// LayeredToneBaseTests.swift: the layered live base (suite-imaging IM-17,
// slice IM-gpu). Two pixel layers and an adjustment layer between them
// composite on the GPU to the CPU's composite within 2 levels; a pixel edit in
// one tile recomposites that region only and reads nothing back; a slider step
// reuses the cached region composite. macOS only (Metal): on Linux this file
// compiles to nothing.
#if canImport(Metal)
import CoreColor
import CoreRaster
import CoreRender
import Metal
import Testing
import SuiteImaging

enum LayeredFixture {
    typealias F = LiveToneFixture

    /// A half-transparent layer with its own pattern, so the stack shows both pixel layers.
    static func top() throws -> PixelBuffer {
        var buffer = try PixelBuffer(width: F.width, height: F.height)
        for y in 0..<F.height {
            for x in 0..<F.width {
                let v = Float((x * 5 + y * 11) % 256) / 255
                try buffer.setPixel(x: x, y: y, RGBA(r: v, g: 1 - v, b: 0.5, a: (x / 8 + y / 8) % 2 == 0 ? 0.5 : 1))
            }
        }
        return buffer
    }

    static let adjustment = ImagingProgram.program(F.settings)

    /// The stack, bottom first: a picture, an adjustment layer over it, then the half-transparent layer at 0.8.
    static func layers(top: PixelBuffer) throws -> [LayeredToneBase.Layer] {
        [LayeredToneBase.Layer(.pixels(try F.picture())),
         LayeredToneBase.Layer(.adjustment(adjustment)),
         LayeredToneBase.Layer(.pixels(top), opacity: 0.8)]
    }

    /// The CPU reference of the same stack, then `program`, as display bytes.
    static func cpu(top: PixelBuffer, program: [ToneProgram.Operation] = []) throws -> [UInt8] {
        let backend = CPUBackend()
        var picture = try backend.blank(width: F.width, height: F.height)
        try backend.composite(try backend.surface(try F.picture()), onto: &picture, x: 0, y: 0, mode: .normal, opacity: 1)
        picture = try backend.adjusted(picture, tone: try ToneProgram(operations: adjustment))
        try backend.composite(try backend.surface(top), onto: &picture, x: 0, y: 0, mode: .normal, opacity: 0.8)
        picture = try backend.adjusted(picture, tone: try ToneProgram(operations: program))
        return try backend.display(picture, colorSpace: .sRGB)
    }

    /// The same stack with no adjustment layer, to show the layer changes the picture.
    static func cpuUnadjusted(top: PixelBuffer) throws -> [UInt8] {
        let backend = CPUBackend()
        var picture = try backend.blank(width: F.width, height: F.height)
        try backend.composite(try backend.surface(try F.picture()), onto: &picture, x: 0, y: 0, mode: .normal, opacity: 1)
        try backend.composite(try backend.surface(top), onto: &picture, x: 0, y: 0, mode: .normal, opacity: 0.8)
        return try backend.display(picture, colorSpace: .sRGB)
    }
}

@Suite(.enabled(if: LiveToneFixture.device != nil, "needs a Metal device"))
struct LayeredToneBaseTests {
    typealias F = LiveToneFixture
    typealias L = LayeredFixture

    @Test func adjustmentLayersRun() throws {
        let device = try #require(F.device)
        let top = try L.top()
        let base = try LayeredToneBase(device: device, width: F.width, height: F.height, layers: try L.layers(top: top),
                                       tileSize: F.tile)
        let target = try F.target(device)
        try base.draw([], into: target, region: F.whole)
        #expect(F.drift(F.bytes(target), try L.cpu(top: top)) <= 2, "the GPU composite drifts from the CPU's")
        #expect(F.drift(F.bytes(target), try L.cpuUnadjusted(top: top)) > 2, "the adjustment layer changes the picture")
        #expect(base.uploads == 8, "each pixel layer is uploaded once, one surface per tile")
        #expect(base.composites == 4 && base.bytesRead == 0)
    }

    @Test func cacheFollowsEdits() throws {
        let device = try #require(F.device)
        let top = try L.top()
        let base = try LayeredToneBase(device: device, width: F.width, height: F.height, layers: try L.layers(top: top),
                                       tileSize: F.tile)
        let target = try F.target(device)
        try base.draw([], into: target, region: F.whole)
        let before = F.bytes(target)
        let (uploads, composites) = (base.uploads, base.composites)
        let damage = TileRect(x: 70, y: 70, width: 6, height: 6)
        let edited = try F.edited(top, damage)
        try base.replacePixels(at: 2, edited, damaged: [damage])
        #expect(base.uploads == uploads + 1, "only the damaged tile of the edited layer is uploaded again")
        try base.draw([], into: target, region: F.whole)
        let after = F.bytes(target)
        #expect(base.composites == composites + 1, "only the damaged region is composited again")
        #expect(base.bytesRead == 0, "an edit reads nothing back")
        #expect(F.drift(after, try L.cpu(top: edited)) <= 2, "the edit shows")
        #expect(F.drift(after, before, in: TileRect(x: 0, y: 0, width: F.width, height: F.tile)) == 0,
                "the other regions keep their pixels")
    }

    @Test func stepReusesComposite() throws {
        let device = try #require(F.device)
        let top = try L.top()
        let base = try LayeredToneBase(device: device, width: F.width, height: F.height, layers: try L.layers(top: top),
                                       tileSize: F.tile)
        let target = try F.target(device)
        try base.draw([], into: target, region: F.whole)
        let (uploads, composites, writes) = (base.uploads, base.composites, base.writes)
        var step = F.settings
        step.exposure = -0.3
        try base.draw(ImagingProgram.program(step), into: target, region: F.whole)
        #expect(base.composites == composites, "a step reuses each region's composite")
        #expect(base.uploads == uploads && base.bytesRead == 0, "a step uploads and reads nothing")
        #expect(base.writes == writes + 4, "a step is one display write per region")
        #expect(F.drift(F.bytes(target), try L.cpu(top: top, program: ImagingProgram.program(step))) <= 2,
                "the step is written over the composite")
    }
}
#endif
