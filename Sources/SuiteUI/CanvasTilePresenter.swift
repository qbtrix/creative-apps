// CanvasTilePresenter.swift: the canvas host's live Metal presenter (render
// adoption R1). The host hands it every tile it shows (`show`); it keeps the
// document as one rgba8 texture, writing only the tiles that changed since
// the last frame (all of them when the size changes or the texture is new),
// and each `present` scales that texture into the drawable with MPS's
// Lanczos filter (premultiplied sRGB in, the layer's sRGB out), or bilinear
// when Lanczos's own temporary texture would pass the device's size limit
// (a tiny drawable, or a document near the limit): Metal aborts on that
// allocation instead of failing it. The tiles'
// pixels are the app's already: on a GPU route they came back from the GPU
// as display bytes, so a frame uploads them again. A tile whose image
// isn't 8-bit premultiplied RGBA at its tile's size is redrawn into that form
// once. A GPU producer can instead write the document texture itself
// (`residentTexture`, render adoption G1): Photo's resident GPU path draws
// its composite straight into it, so nothing is uploaded or read back. macOS
// only.
import CoreGraphics
import Metal
import MetalPerformanceShaders
import QuartzCore

@MainActor
public final class CanvasTilePresenter: MetalPresenting {
    /// Frames handed to a drawable.
    public private(set) var presented = 0
    private var size = CGSize.zero
    private var images: [CanvasTileRect: CGImage] = [:]
    private var dirty: Set<CanvasTileRect> = []
    /// The document texture; nil until the first present.
    public private(set) var texture: (any MTLTexture)?
    private var queue: (any MTLCommandQueue)?
    private var lanczos: MPSImageLanczosScale?
    private var bilinear: MPSImageBilinearScale?

    public init() {}

    public func show(_ tiles: [CanvasTile], documentSize: CGSize) {
        if documentSize != size {
            (size, images, dirty, texture) = (documentSize, [:], [], nil)
        }
        for tile in tiles {
            images[tile.rect] = tile.image
            dirty.insert(tile.rect)
        }
    }

    public func present(_ drawable: any CAMetalDrawable, on layer: CAMetalLayer) {
        guard let device = layer.device, size.width >= 1, size.height >= 1 else { return }
        if queue == nil { queue = device.makeCommandQueue() }
        guard let source = upload(on: device), let buffer = queue?.makeCommandBuffer() else { return }
        let target = drawable.texture
        let scaler: MPSImageScale?
        if Self.lanczosFits(source: (source.width, source.height), destination: (target.width, target.height),
                            limit: Self.maxTextureSide(device)) {
            if lanczos?.device !== device { lanczos = MPSImageLanczosScale(device: device) }
            scaler = lanczos
        } else {
            if bilinear?.device !== device { bilinear = MPSImageBilinearScale(device: device) }
            scaler = bilinear
        }
        scaler?.encode(commandBuffer: buffer, sourceTexture: source, destinationTexture: target)
        buffer.present(drawable)
        buffer.commit()
        presented += 1
    }

    /// Whether MPS's Lanczos scale of `source` into `destination` keeps its temporary texture within
    /// `limit` on both sides. That texture is the source side plus three filter widths each way, about
    /// 6 x source / destination (measured: 7680 x 4320 into 1 x 1 asks for 30238 high).
    /// ponytail: measured, not documented; bilinear past it aliases, halve-then-Lanczos if that shows.
    nonisolated static func lanczosFits(source: (Int, Int), destination: (Int, Int), limit: Int) -> Bool {
        let fits = { (from: Int, to: Int) in from + 6 * ((from + max(to, 1) - 1) / max(to, 1)) + 2 <= limit }
        return fits(source.0, destination.0) && fits(source.1, destination.1)
    }

    /// The largest 2D texture side `device` makes: 16384 on Apple-family 3+ and Mac-family GPUs,
    /// 8192 before (Metal feature set tables; no device property reports it).
    nonisolated static func maxTextureSide(_ device: any MTLDevice) -> Int {
        device.supportsFamily(.apple3) || device.supportsFamily(.mac2) ? 16384 : 8192
    }

    /// The document texture for a GPU producer to write straight into (resident rendering): `width` x
    /// `height`, rgba8 premultiplied sRGB, shader-writable, on `device`. Made (or remade, for a new size or
    /// device) here, so the tiles shown before are dropped: the producer's writes are the picture from now on,
    /// and a later `show` of tiles writes over them as before. Nil when Metal won't make it.
    public func residentTexture(on device: any MTLDevice, width: Int, height: Int) -> (any MTLTexture)? {
        let wanted = CGSize(width: width, height: height)
        if let texture, texture.device.registryID == device.registryID, size == wanted, texture.usage.contains(.shaderWrite) {
            (images, dirty) = ([:], [])
            return texture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: max(width, 1), height: max(height, 1), mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
        (size, images, dirty, texture) = (wanted, [:], [], device.makeTexture(descriptor: descriptor))
        return texture
    }

    /// The document texture with every dirty tile written; nil when Metal won't make it.
    private func upload(on device: any MTLDevice) -> (any MTLTexture)? {
        // The same GPU by registry id: two MTLDevice objects for one GPU must not drop a texture a producer wrote.
        if texture == nil || texture?.device.registryID != device.registryID {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: Int(size.width), height: Int(size.height), mipmapped: false)
            descriptor.usage = [.shaderRead, .shaderWrite]
            descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
            texture = device.makeTexture(descriptor: descriptor)
            dirty = Set(images.keys)
        }
        guard let texture else { return nil }
        for rect in dirty {
            guard let image = images[rect], let (bytes, row) = Self.rgba(image, width: rect.width, height: rect.height)
            else { continue }
            bytes.withUnsafeBytes { raw in
                guard let base = raw.baseAddress else { return }
                texture.replace(
                    region: MTLRegionMake2D(rect.x, rect.y, rect.width, rect.height), mipmapLevel: 0, withBytes: base,
                    bytesPerRow: row)
            }
        }
        dirty = []
        return texture
    }

    /// `image` at `width` x `height` as 8-bit premultiplied RGBA rows and their stride: its own bytes
    /// when it already is that at that size, else redrawn once (scaled, as a tile layer stretches it).
    /// Nil only when CoreGraphics refuses it.
    nonisolated static func rgba(_ image: CGImage, width: Int, height: Int) -> (Data, Int)? {
        let order = image.bitmapInfo.intersection(.byteOrderMask)
        if image.width == width, image.height == height, image.alphaInfo == .premultipliedLast,
            image.bitsPerComponent == 8, image.bitsPerPixel == 32,
            order == [] || order == .byteOrder32Big, let data = image.dataProvider?.data as Data?
        {
            return (data, image.bytesPerRow)
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = context.data else { return nil }
        return (Data(bytes: data, count: width * height * 4), width * 4)
    }
}
