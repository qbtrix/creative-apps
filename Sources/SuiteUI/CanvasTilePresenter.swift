// CanvasTilePresenter.swift: the canvas host's live Metal presenter (render
// adoption R1). The host hands it every tile it shows (`show`); it keeps the
// document as one rgba8 texture, writing only the tiles that changed since
// the last frame (all of them when the size changes or the texture is new),
// and each `present` scales that texture into the drawable with MPS's
// Lanczos filter (premultiplied sRGB in, the layer's sRGB out). The tiles'
// pixels are the app's already: on a GPU route they came back from the GPU
// as display bytes, so a frame uploads them again (a G1 item: present a
// render surface directly once core can hand one out). A tile whose image
// isn't 8-bit premultiplied RGBA at its tile's size is redrawn into that form
// once. macOS only.
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
    private var scaler: MPSImageLanczosScale?

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
        if scaler?.device !== device { scaler = MPSImageLanczosScale(device: device) }
        scaler?.encode(commandBuffer: buffer, sourceTexture: source, destinationTexture: drawable.texture)
        buffer.present(drawable)
        buffer.commit()
        presented += 1
    }

    /// The document texture with every dirty tile written; nil when Metal won't make it.
    private func upload(on device: any MTLDevice) -> (any MTLTexture)? {
        if texture == nil || texture?.device !== device {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rgba8Unorm, width: Int(size.width), height: Int(size.height), mipmapped: false)
            descriptor.usage = .shaderRead
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
