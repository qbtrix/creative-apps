// HaloRenderEdgeTests.swift: edge cases for rendering a composition's solids
// with CoreRaster: rectangles off or across the frame, sub-pixel rectangles,
// odd sizes and scales, every blend mode, frames at the composition's ends,
// out-of-range colors and the display bytes the viewer shows. Runs on Linux
// and macOS.
import CoreRaster
import HaloModel
import Testing

private let red = HaloLayerColor(red: 1, green: 0, blue: 0)
private let blue = HaloLayerColor(red: 0, green: 0, blue: 1)

private func layer(
    _ id: String, _ kind: HaloLayerKind = .solid, color: HaloLayerColor = red, opacity: Double = 1,
    mode: BlendMode = .normal, frames: Range<Int> = 0..<30, rect: HaloLayerRect? = nil
) -> HaloLayer {
    HaloLayer(
        id: id, name: id, kind: kind, inFrame: frames.lowerBound, outFrame: frames.upperBound, color: color,
        opacity: opacity, blendMode: mode, rect: rect)
}

/// A `width` x `height` composition of 30 frames; `layers` top first.
private func comp(_ layers: [HaloLayer], width: Int = 40, height: Int = 20) -> HaloComposition {
    HaloComposition(
        id: "c", name: "C", width: width, height: height, framesPerSecond: 30, durationFrames: 30, layers: layers)
}

/// Every pixel's display bytes, four per pixel.
private func bytes(_ frame: HaloRenderedFrame?) throws -> [UInt8] {
    try #require(frame?.pixels).rgba8()
}

private func pixel(_ frame: HaloRenderedFrame?, x: Int, y: Int) throws -> RGBA {
    try #require(frame?.pixels).pixel(x: x, y: y)
}

@Test func aSolidsColorReachesTheDisplayBytesUnchanged() throws {
    // The default solid color goes to linear light and back to the same sRGB bytes.
    let color = HaloLayerKind.solid.defaultColor
    let frame = comp([layer("a", color: color)]).renderFrame(at: 0)
    let expected = [color.red, color.green, color.blue].map { UInt8(($0 * 255).rounded()) } + [255]
    #expect(Array(try bytes(frame).prefix(4)) == expected)
}

@Test func aRectangleOffTheFrameDrawsNothing() throws {
    let rects = [
        HaloLayerRect(x: 40, y: 0, width: 10, height: 10),
        HaloLayerRect(x: -50, y: 0, width: 10, height: 10),
        HaloLayerRect(x: 0, y: 20, width: 10, height: 10),
        HaloLayerRect(x: 0, y: -20, width: 40, height: 20),
    ]
    for rect in rects {
        let frame = comp([layer("a", rect: rect)]).renderFrame(at: 0)
        #expect(try bytes(frame).allSatisfy { $0 == 0 }, "rect \(rect)")
    }
}

@Test func aHugeRectangleCoversTheWholeFrame() throws {
    let rect = HaloLayerRect(x: -1e300, y: -1e300, width: 1e301, height: 1e301)
    let full = comp([layer("a")]).renderFrame(at: 0)
    let frame = comp([layer("a", rect: rect)]).renderFrame(at: 0)
    #expect(frame?.pixels == full?.pixels)
}

@Test func anInfiniteRectangleDrawsNothingAndKeepsTheRest() throws {
    let rect = HaloLayerRect(x: 0, y: 0, width: .infinity, height: 10)
    let backdrop = comp([layer("bottom", color: blue)]).renderFrame(at: 0)
    let frame = comp([layer("top", rect: rect), layer("bottom", color: blue)]).renderFrame(at: 0)
    #expect(frame?.pixels == backdrop?.pixels)
}

@Test func aZeroSizeRectangleDrawsNothing() throws {
    let frame = comp([layer("a", rect: HaloLayerRect(x: 8, y: 8, width: 0, height: 0))]).renderFrame(at: 0)
    #expect(try bytes(frame).allSatisfy { $0 == 0 })
}

@Test func aSubPixelRectangleGivesPartialCoverage() throws {
    // 2 x 2 composition pixels are a quarter of one preview pixel each way: 1/4 coverage.
    let frame = comp([layer("a", rect: HaloLayerRect(x: 0, y: 0, width: 2, height: 2))]).renderFrame(at: 0)
    let p = try pixel(frame, x: 0, y: 0)
    #expect(p.a > 0 && p.a < 1)
    #expect(abs(p.a - 0.25) < 0.05)
    // Premultiplied: color never exceeds alpha.
    #expect(p.r <= p.a)
    #expect(try pixel(frame, x: 1, y: 0).a == 0)
}

@Test func aRectangleScalesWithTheRenderScale() throws {
    // The left half of the composition is the left half of the frame at any scale.
    let rect = HaloLayerRect(x: 0, y: 0, width: 20, height: 20)
    for scale in [1, 2, 4, 5] {
        let frame = try #require(comp([layer("a", rect: rect)]).renderFrame(at: 0, scale: scale))
        let w = frame.pixels.width
        #expect(try frame.pixels.pixel(x: 0, y: 0).a == 1, "scale \(scale)")
        #expect(try frame.pixels.pixel(x: w - 1, y: 0).a == 0, "scale \(scale)")
    }
}

@Test func oddSizesRoundTheFrameDownButNeverToZero() throws {
    #expect(comp([], width: 1921, height: 1081).renderFrame(at: 0)?.pixels.width == 480)
    #expect(comp([], width: 1921, height: 1081).renderFrame(at: 0)?.pixels.height == 270)
    let tiny = try #require(comp([layer("a")], width: 1, height: 1).renderFrame(at: 0))
    #expect(tiny.pixels.width == 1 && tiny.pixels.height == 1)
    #expect(try tiny.pixels.pixel(x: 0, y: 0).a == 1)
    let huge = try #require(comp([], width: 40, height: 20).renderFrame(at: 0, scale: .max))
    #expect(huge.pixels.width == 1 && huge.pixels.height == 1)
}

@Test func aScaleBelowOneOrAnEmptySizeRendersNothing() {
    #expect(comp([]).renderFrame(at: 0, scale: 0) == nil)
    #expect(comp([]).renderFrame(at: 0, scale: -4) == nil)
    #expect(comp([], width: 0, height: 20).renderFrame(at: 0) == nil)
    #expect(comp([], width: 40, height: -1).renderFrame(at: 0) == nil)
}

@Test func theLargestCompositionRendersAtPreviewSize() throws {
    let side = CompositionSettings.sizeRange.upperBound
    let frame = try #require(comp([layer("a")], width: side, height: side).renderFrame(at: 0))
    #expect(frame.pixels.width == side / 4 && frame.pixels.height == side / 4)
}

@Test func everyBlendModeOverAnOpaqueBackdropStaysOpaqueAndFinite() throws {
    for mode in BlendMode.allCases {
        let frame = comp([layer("top", color: blue, mode: mode), layer("bottom")]).renderFrame(at: 0)
        let p = try pixel(frame, x: 0, y: 0)
        #expect(p.a == 1, "\(mode)")
        #expect([p.r, p.g, p.b].allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 1 }, "\(mode)")
    }
}

@Test func anyBlendModeOverNothingIsTheLayerItself() throws {
    // Over a transparent backdrop every mode shows the source unchanged (W3C).
    let alone = comp([layer("a", color: blue)]).renderFrame(at: 0)
    for mode in BlendMode.allCases {
        let frame = comp([layer("a", color: blue, mode: mode)]).renderFrame(at: 0)
        #expect(frame?.pixels == alone?.pixels, "\(mode)")
    }
}

@Test func theOutPointIsExclusiveAndTheInPointInclusive() throws {
    let c = comp([layer("a", frames: 10..<20)])
    #expect(try pixel(c.renderFrame(at: 9), x: 0, y: 0).a == 0)
    #expect(try pixel(c.renderFrame(at: 10), x: 0, y: 0).a == 1)
    #expect(try pixel(c.renderFrame(at: 19), x: 0, y: 0).a == 1)
    #expect(try pixel(c.renderFrame(at: 20), x: 0, y: 0).a == 0)
}

@Test func extremeFrameNumbersRenderWithoutCrashing() {
    let c = comp([layer("a", frames: 0..<30), layer("b", .text)])
    for f in [Int.min, -1, 30, Int.max] {
        let frame = c.renderFrame(at: f)
        #expect(frame?.frame == f)
        #expect(frame?.skippedLayerCount == 0)
    }
}

@Test func outOfRangeColorsClampInsteadOfVanishing() throws {
    let wild = HaloLayerColor(red: .infinity, green: -.infinity, blue: .nan)
    let frame = comp([layer("a", color: wild)]).renderFrame(at: 0)
    #expect(Array(try bytes(frame).prefix(4)) == [255, 0, 0, 255])
}

@Test func onlyVisibleTextCountsAsSkipped() {
    let c = comp([
        layer("shape", .shape), layer("text", .text, frames: 20..<30), layer("null", .null), layer("solid"),
        layer("text2", .text, frames: 25..<30),
    ])
    #expect(c.renderFrame(at: 0)?.skippedLayerCount == 0)
    #expect(c.renderFrame(at: 0)?.note == nil)
    #expect(c.renderFrame(at: 20)?.note == "1 text layer not drawn.")
    #expect(c.renderFrame(at: 25)?.skippedLayerCount == 2)
    #expect(c.renderFrame(at: 25)?.note == "2 text layers not drawn.")
}

@Test func aSkippedLayerDoesNotChangeThePixels() {
    let solids = comp([layer("a", color: blue, mode: .screen), layer("b")]).renderFrame(at: 0)
    let mixed = comp([layer("n", .null), layer("a", color: blue, mode: .screen), layer("t", .text), layer("b")])
        .renderFrame(at: 0)
    #expect(mixed?.pixels == solids?.pixels)
}

@Test func manyStackedSolidsRenderAtPreviewSize() throws {
    // 24 half-transparent solids over 1080p: the frame comes back and is opaque.
    let layers = (0..<24).map { i in
        layer("l\(i)", color: i.isMultiple(of: 2) ? red : blue, opacity: 0.5,
              rect: HaloLayerRect(x: Double(i), y: Double(i), width: 1000, height: 600))
    } + [layer("bg")]
    let frame = try #require(comp(layers, width: 1920, height: 1080).renderFrame(at: 0))
    #expect(frame.pixels.width == 480 && frame.pixels.height == 270)
    #expect(try frame.pixels.pixel(x: 100, y: 100).a == 1)
}

@Test func theProjectRendersTheSelectedCompositionOnly() throws {
    var project = HaloProject()
    #expect(project.renderSelectedFrame(at: 0) == nil)
    project.newComposition()
    project.newLayer(.solid)
    let first = try #require(project.renderSelectedFrame(at: 0))
    #expect(try first.pixels.pixel(x: 0, y: 0).a == 1)
    project.newComposition()
    let second = try #require(project.renderSelectedFrame(at: 0))
    #expect(try second.pixels.pixel(x: 0, y: 0).a == 0)
}

@Test func settingOpacityAndBlendModeChangesTheRender() throws {
    var project = HaloProject()
    project.newComposition()
    project.newLayer(.solid)
    project.setSelectedLayerOpacity(0)
    #expect(try pixel(project.renderSelectedFrame(at: 0), x: 0, y: 0).a == 0)
    project.setSelectedLayerOpacity(.nan)
    #expect(project.selectedLayer?.opacity == 0)
    project.setSelectedLayerOpacity(7)
    #expect(project.selectedLayer?.opacity == 1)
    #expect(try pixel(project.renderSelectedFrame(at: 0), x: 0, y: 0).a == 1)
    project.setSelectedLayerBlendMode(.difference)
    #expect(project.selectedLayer?.blendMode == .difference)
}

@Test func renderingNeverChangesTheProject() {
    var project = HaloProject()
    project.newComposition()
    project.newLayer(.solid)
    let before = project
    _ = project.renderSelectedFrame(at: 0)
    _ = project.renderSelectedFrame(at: .max)
    #expect(project == before)
}
