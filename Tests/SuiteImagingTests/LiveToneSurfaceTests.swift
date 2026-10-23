// LiveToneSurfaceTests.swift: the live GPU tone surface (suite-imaging IM-5,
// slice IM-m, journey MJ-IM). A slider step is one display write over the
// resident base: nothing uploaded, sharpened again or read back; the written
// picture equals `ImagingProgram.adjustments` run on the CPU within 2 levels;
// a pixel edit re-uploads only its damaged tiles and re-sharpens around them.
// macOS only (Metal): on Linux this file compiles to nothing.
#if canImport(Metal)
import CoreColor
import CoreRaster
import CoreRender
import Metal
import Testing
import SuiteImaging

enum LiveToneFixture {
    static let device = MTLCreateSystemDefaultDevice()
    static let (width, height, tile) = (128, 96, 64)

    /// An opaque picture with detail in every tile, so a sharpen or a tone step shows.
    static func picture(seed: Int = 0) throws -> PixelBuffer {
        var buffer = try PixelBuffer(width: width, height: height)
        for y in 0..<height {
            for x in 0..<width {
                let r = Float((x * 7 + y * 3 + seed) % 256) / 255
                let g = Float((x * 2 + y * 5 + seed * 3) % 256) / 255
                let b = ((x / 4 + y / 4) % 2 == 0) ? Float(0.2) : Float(0.8)
                try buffer.setPixel(x: x, y: y, RGBA(r: r, g: g, b: b, a: 1))
            }
        }
        return buffer
    }

    /// `base` with the rectangle's pixels inverted: a pixel edit inside one tile.
    static func edited(_ base: PixelBuffer, _ rect: TileRect) throws -> PixelBuffer {
        var out = base
        for y in rect.y..<(rect.y + rect.height) {
            for x in rect.x..<(rect.x + rect.width) {
                let p = try base.pixel(x: x, y: y)
                try out.setPixel(x: x, y: y, RGBA(r: 1 - p.r, g: 1 - p.g, b: 1 - p.b, a: 1))
            }
        }
        return out
    }

    static let settings = AdjustSettings(
        exposure: 0.4,
        levels: AdjustLevels(inputBlack: 0.05, inputWhite: 0.9, gamma: 1.2, outputBlack: 0.02, outputWhite: 0.98),
        curve: AdjustCurve(points: [AdjustCurvePoint(x: 0, y: 0), AdjustCurvePoint(x: 0.5, y: 0.6), AdjustCurvePoint(x: 1, y: 1)]),
        hueSaturation: AdjustHueSaturation(hue: 20, saturation: 15, lightness: 0))

    static let unsharp = LiveToneSurface.UnsharpParameters(amount: 0.8, sigma: 1.5, threshold: 0)

    static func target(_ device: any MTLDevice) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: width, height: height,
                                                                  mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        #if os(macOS)
        descriptor.storageMode = .managed
        #endif
        return try #require(device.makeTexture(descriptor: descriptor))
    }

    /// The test's own readback of what the surface wrote.
    static func bytes(_ texture: any MTLTexture) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: width * height * 4)
        out.withUnsafeMutableBytes { raw in
            if let base = raw.baseAddress {
                texture.getBytes(base, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            }
        }
        return out
    }

    /// The CPU reference: `base` sharpened (when asked), then each of `steps`, as display bytes.
    static func cpu(_ base: PixelBuffer, steps: [ToneAdjustment],
                    unsharp: LiveToneSurface.UnsharpParameters? = nil) throws -> [UInt8] {
        var picture = base
        if let unsharp {
            picture = try picture.unsharpMask(amount: unsharp.amount, sigma: unsharp.sigma, threshold: unsharp.threshold)
        }
        let backend = CPUBackend()
        var surface = try backend.surface(picture)
        for step in steps { surface = try backend.adjusted(surface, step) }
        return try backend.display(surface, colorSpace: .sRGB)
    }

    /// The largest per-component difference within `rect`.
    static func drift(_ a: [UInt8], _ b: [UInt8], in rect: TileRect = TileRect(x: 0, y: 0, width: width, height: height)) -> Int {
        var worst = 0
        for y in rect.y..<(rect.y + rect.height) {
            for x in rect.x..<(rect.x + rect.width) {
                for c in 0..<4 {
                    let i = (y * width + x) * 4 + c
                    worst = max(worst, abs(Int(a[i]) - Int(b[i])))
                }
            }
        }
        return worst
    }

    static let whole = TileRect(x: 0, y: 0, width: width, height: height)
}

@Suite(.enabled(if: LiveToneFixture.device != nil, "needs a Metal device"))
struct LiveToneSurfaceTests {
    typealias F = LiveToneFixture

    @Test func stepIsOneWrite() throws {
        let device = try #require(F.device)
        let surface = try LiveToneSurface(device: device, base: try F.picture(), tileSize: F.tile)
        let target = try F.target(device)
        let region = TileRect(x: 0, y: 0, width: F.tile, height: F.tile)
        try surface.draw(ImagingProgram.program(F.settings), unsharp: F.unsharp, into: target, region: region)
        let (uploads, sharpened, read, writes) = (surface.uploads, surface.sharpenPasses, surface.bytesRead, surface.writes)
        #expect(uploads == 4, "the base is uploaded once, one surface per tile")
        var step = F.settings
        step.exposure = 0.6
        try surface.draw(ImagingProgram.program(step), unsharp: F.unsharp, into: target, region: region)
        #expect(surface.writes == writes + 1, "a step in one tile is one display write")
        #expect(surface.uploads == uploads, "a step uploads nothing")
        #expect(surface.sharpenPasses == sharpened, "a step reuses the cached sharpen")
        #expect(surface.bytesRead == read, "a step reads nothing back")
        try surface.draw(ImagingProgram.program(F.settings), unsharp: nil, into: target, region: region)
        #expect(surface.uploads == uploads && surface.bytesRead == read && surface.writes == writes + 2)
    }

    @Test func matchesCpu() throws {
        let device = try #require(F.device)
        let base = try F.picture()
        let surface = try LiveToneSurface(device: device, base: base, tileSize: F.tile)
        let target = try F.target(device)
        try surface.draw(ImagingProgram.program(F.settings), unsharp: nil, into: target, region: F.whole)
        let expected = try F.cpu(base, steps: ImagingProgram.adjustments(F.settings))
        #expect(F.drift(F.bytes(target), expected) <= 2, "the GPU picture drifts from ImagingProgram.adjustments on the CPU")
        #expect(F.drift(F.bytes(target), try F.cpu(base, steps: [])) > 2, "the program changes the picture")
        try surface.draw(ImagingProgram.program(F.settings), unsharp: F.unsharp, into: target, region: F.whole)
        let sharpened = try F.cpu(base, steps: ImagingProgram.adjustments(F.settings), unsharp: F.unsharp)
        #expect(F.drift(F.bytes(target), sharpened) <= 2, "the sharpened picture drifts from the CPU's, seams included")
    }

    @Test func damagedTileReuploadsOnlyThatTile() throws {
        let device = try #require(F.device)
        let base = try F.picture()
        let surface = try LiveToneSurface(device: device, base: base, tileSize: F.tile)
        let target = try F.target(device)
        try surface.draw([], unsharp: nil, into: target, region: F.whole)
        let before = F.bytes(target)
        let uploads = surface.uploads
        let damage = TileRect(x: 70, y: 70, width: 6, height: 6)
        let edited = try F.edited(base, damage)
        surface.replaceBase(edited, damaged: [damage])
        #expect(surface.uploads == uploads + 1, "only the damaged tile is uploaded again")
        try surface.draw([], unsharp: nil, into: target, region: F.whole)
        let after = F.bytes(target)
        #expect(F.drift(after, try F.cpu(edited, steps: [])) <= 2, "the edit shows")
        #expect(F.drift(after, before, in: TileRect(x: 0, y: 0, width: F.width, height: F.tile)) == 0, "the other tiles keep their pixels")
    }

    @Test func sharpenFollowsBase() throws {
        let device = try #require(F.device)
        let base = try F.picture()
        let surface = try LiveToneSurface(device: device, base: base, tileSize: F.tile)
        let target = try F.target(device)
        try surface.draw([], unsharp: F.unsharp, into: target, region: F.whole)
        let damage = TileRect(x: 10, y: 10, width: 20, height: 20)
        let edited = try F.edited(base, damage)
        surface.replaceBase(edited, damaged: [damage])
        try surface.draw([], unsharp: F.unsharp, into: target, region: F.whole)
        #expect(F.drift(F.bytes(target), try F.cpu(edited, steps: [], unsharp: F.unsharp)) <= 2,
                "the sharpen is redone over the edited base")
    }
}
#endif
