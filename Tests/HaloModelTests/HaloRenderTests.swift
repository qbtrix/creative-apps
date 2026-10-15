// HaloRenderTests.swift: rendering a composition's solids into one frame with
// CoreRaster: blend order, opacity, in and out points, rectangles, the preview
// size and the undrawn-text note. Runs on Linux and macOS.
import CoreRaster
import HaloModel
import Testing

private let yellow = HaloLayerColor(red: 1, green: 1, blue: 0)
private let cyan = HaloLayerColor(red: 0, green: 1, blue: 1)

private func solid(
    _ id: String, _ color: HaloLayerColor, opacity: Double = 1, mode: BlendMode = .normal,
    frames: Range<Int> = 0..<30, rect: HaloLayerRect? = nil
) -> HaloLayer {
    HaloLayer(
        id: id, name: id, kind: .solid, inFrame: frames.lowerBound, outFrame: frames.upperBound, color: color,
        opacity: opacity, blendMode: mode, rect: rect)
}

/// A 40 x 20 composition (10 x 5 at preview size); `layers` top first.
private func comp(_ layers: [HaloLayer]) -> HaloComposition {
    HaloComposition(id: "c", name: "C", width: 40, height: 20, framesPerSecond: 30, durationFrames: 30, layers: layers)
}

/// The display bytes of pixel (x, y) of `frame`.
private func bytes(_ frame: HaloRenderedFrame?, x: Int = 0, y: Int = 0) throws -> [UInt8] {
    let pixels = try #require(frame?.pixels)
    let all = try pixels.rgba8()
    let i = (y * pixels.width + x) * 4
    return Array(all[i..<i + 4])
}

@Test func twoSolidsInMultiplyGiveTheProduct() throws {
    let frame = comp([solid("top", cyan, mode: .multiply), solid("bottom", yellow)]).renderFrame(at: 0)
    #expect(try bytes(frame) == [0, 255, 0, 255])
}

@Test func layersCompositeBottomToTop() throws {
    // Normal mode: the top layer hides the bottom one, whichever color it is.
    #expect(try bytes(comp([solid("a", cyan), solid("b", yellow)]).renderFrame(at: 0)) == [0, 255, 255, 255])
    #expect(try bytes(comp([solid("b", yellow), solid("a", cyan)]).renderFrame(at: 0)) == [255, 255, 0, 255])
}

@Test func aLayerAtOpacityZeroLeavesTheBackdropUnchanged() {
    let backdrop = comp([solid("bottom", yellow)]).renderFrame(at: 0)
    let frame = comp([solid("top", cyan, opacity: 0), solid("bottom", yellow)]).renderFrame(at: 0)
    #expect(frame?.pixels == backdrop?.pixels)
}

@Test func halfOpacityMixesInLinearLight() throws {
    let frame = comp([solid("top", HaloLayerColor(red: 1, green: 1, blue: 1), opacity: 0.5),
                      solid("bottom", HaloLayerColor(red: 0, green: 0, blue: 0))]).renderFrame(at: 0)
    let pixel = try #require(try frame?.pixels.pixel(x: 0, y: 0))
    #expect(abs(pixel.r - 0.5) < 0.0001 && pixel.a == 1)
}

@Test func aLayerOutsideItsInAndOutPointsIsAbsent() {
    let backdrop = comp([solid("bottom", yellow)]).renderFrame(at: 5)
    let late = comp([solid("top", cyan, frames: 10..<20), solid("bottom", yellow)])
    #expect(late.renderFrame(at: 5)?.pixels == backdrop?.pixels)
    #expect(late.renderFrame(at: 20)?.pixels == backdrop?.pixels)
    #expect(late.renderFrame(at: 10)?.pixels != backdrop?.pixels)
}

@Test func anEmptyCompositionRendersAFullyTransparentFrame() throws {
    let frame = try #require(comp([]).renderFrame(at: 0))
    #expect(try frame.pixels.rgba8().allSatisfy { $0 == 0 })
    #expect(frame.skippedLayerCount == 0 && frame.note == nil)
}

@Test func aSolidFillsOnlyItsRectangle() throws {
    // x 0..<20 of 40 is preview x 0..<5 of 10.
    let frame = comp([solid("half", cyan, rect: HaloLayerRect(x: 0, y: 0, width: 20, height: 20))]).renderFrame(at: 0)
    #expect(try bytes(frame, x: 4) == [0, 255, 255, 255])
    #expect(try bytes(frame, x: 5) == [0, 0, 0, 0])
}

@Test func overlappingSolidsBlendOnlyWhereTheyOverlap() throws {
    let frame = comp([
        solid("left", cyan, mode: .multiply, rect: HaloLayerRect(x: 0, y: 0, width: 24, height: 20)),
        solid("right", yellow, rect: HaloLayerRect(x: 16, y: 0, width: 24, height: 20)),
    ]).renderFrame(at: 0)
    #expect(try bytes(frame, x: 1) == [0, 255, 255, 255])
    #expect(try bytes(frame, x: 5) == [0, 255, 0, 255])
    #expect(try bytes(frame, x: 8) == [255, 255, 0, 255])
}

@Test func aRefusedRectangleRendersNothingForThatLayer() {
    let backdrop = comp([solid("bottom", yellow)]).renderFrame(at: 0)
    let bad = solid("bad", cyan, rect: HaloLayerRect(x: 0, y: 0, width: -5, height: .nan))
    #expect(comp([bad, solid("bottom", yellow)]).renderFrame(at: 0)?.pixels == backdrop?.pixels)
}

@Test func thePreviewIsQuarterSize() {
    var project = HaloProject()
    #expect(project.renderSelectedFrame(at: 0) == nil)
    project.newComposition()
    let frame = project.renderSelectedFrame(at: 0)
    #expect(frame?.pixels.width == 480 && frame?.pixels.height == 270)
    #expect(comp([]).renderFrame(at: 0, scale: 0) == nil)
    #expect(comp([]).renderFrame(at: 0, scale: 1000)?.pixels.width == 1)
}

@Test func otherLayerKindsAreSkippedWithANote() throws {
    // .live with no text rasterizer: the text is skipped, the null never counts.
    var project = HaloProject(services: .live)
    project.newComposition()
    project.newLayer(.solid)
    project.newLayer(.text)
    project.newLayer(.null)
    let frame = project.renderSelectedFrame(at: 0)
    #expect(frame?.skippedLayerCount == 1)
    #expect(frame?.note == "1 text layer not drawn.")
    // The solid under them still renders.
    #expect(try bytes(frame).last == 255)
}

@Test func aNullOverASolidLeavesNoNote() throws {
    // #457: a null plus a solid said a layer was skipped.
    var project = HaloProject(services: .live)
    project.newComposition()
    project.newLayer(.solid)
    project.newLayer(.null)
    let frame = try #require(project.renderSelectedFrame(at: 0))
    #expect(frame.skippedLayerCount == 0 && frame.note == nil)
    #expect(try bytes(frame).last == 255)
}

@Test func opacityIsClampedAndDuplicatesKeepBlendAndOpacity() throws {
    #expect(solid("a", cyan, opacity: 2).opacity == 1)
    #expect(solid("a", cyan, opacity: -1).opacity == 0)
    #expect(solid("a", cyan, opacity: .nan).opacity == 1)
    var project = HaloProject()
    project.newComposition()
    project.newLayer(.solid)
    project.setSelectedLayerOpacity(1.5)
    #expect(project.selectedLayer?.opacity == 1)
    project.setSelectedLayerOpacity(.nan)
    project.setSelectedLayerOpacity(0.25)
    project.setSelectedLayerBlendMode(.screen)
    let id = try #require(project.selectedCompositionID)
    project.duplicateComposition(id)
    let layer = try #require(project.selectedComposition?.layers.first)
    #expect(layer.blendMode == .screen && layer.opacity == 0.25 && layer.rect == nil)
}

@Test func blendAndOpacityChangesNeedASelectedLayer() {
    var project = HaloProject()
    project.setSelectedLayerBlendMode(.multiply)
    project.newComposition()
    project.setSelectedLayerOpacity(0)
    #expect(project.selectedComposition?.layers.isEmpty == true)
}
