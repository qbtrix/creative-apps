// FlareColorKeysTests.swift: timeline-keys TK-7 on `.built`. Fill colour, stroke colour and stroke width obey the
// recording rule: recording on, or a track that already has keys, keys the edit at the playhead; off on a static
// property sets the static value. `keyState` follows the playhead by the kernel's frame rules, and the paint key
// toggle adds the key at the playhead or removes it, the last key leaving the property static.
import FlareCore
@testable import FlareModel
import Testing

private let blue = FlareColor(r: 0, g: 0, b: 1), orange = FlareColor(r: 1, g: 149.0 / 255, b: 0)   // 0000FF, FF9500

private func ball() -> FlareWorkspace {
    var w = FlareWorkspace(services: .built)
    w.load(FlareFixtures.bounce)
    w.selectLayer("ball")
    return w
}

private func layer(_ w: FlareWorkspace) -> Layer? {
    w.document?.layers(of: .scene("scene-1"))?.first { $0.id == "ball" }
}

private func colorKeys(_ key: String, _ w: FlareWorkspace) -> [ColorKeyframe] { layer(w)?.colorTracks[key] ?? [] }

@Test func recordingOnKeysAStaticFillAtThePlayheadAndLeavesItsStaticValue() {
    var w = ball()
    let before = layer(w)?.shapes.first?.fill
    w.toggleAutoKey()
    w.setCurrentFrame(30)
    w.setFill(hex: "FF9500")
    #expect(colorKeys("fill.0", w).map(\.frame) == [30])
    #expect(colorKeys("fill.0", w).first?.value == orange)
    #expect(layer(w)?.shapes.first?.fill == before)
    #expect(w.paint?.fillHex == "FF9500")
    w.undo()
    #expect(colorKeys("fill.0", w).isEmpty)
}

@Test func recordingOnAtFrame30AddsAKeyThereAndKeepsFrameZerosKey() {
    var w = ball()
    w.setFill(hex: "0000FF")
    w.togglePaintKey(.fill)
    w.toggleAutoKey()
    w.setCurrentFrame(30)
    w.setFill(hex: "FF9500")
    #expect(colorKeys("fill.0", w).map(\.frame) == [0, 30])
    #expect(colorKeys("fill.0", w).map(\.value) == [blue, orange])
}

@Test func recordingOnKeysStrokeColourAndWidth() {
    var w = ball()
    w.setStrokeWidth(2)
    w.toggleAutoKey()
    w.setCurrentFrame(12)
    w.setStrokeColor(hex: "0000FF")
    w.setStrokeWidth(6)
    #expect(colorKeys("stroke.0", w).map(\.frame) == [12])
    #expect(layer(w)?.tracks["strokeWidth.0"]?.map(\.frame) == [12])
    #expect(layer(w)?.tracks["strokeWidth.0"]?.first?.value == 6)
    #expect(layer(w)?.shapes.first?.stroke?.width == 2)
}

@Test func recordingOffOnAnAnimatedFillKeysInsteadOfFlattening() {
    var w = ball()
    w.setFill(hex: "0000FF")
    w.togglePaintKey(.fill)
    w.setCurrentFrame(30)
    w.togglePaintKey(.fill)
    let staticFill = layer(w)?.shapes.first?.fill
    #expect(!w.autoKey)
    w.setCurrentFrame(15)
    w.setFill(hex: "FF9500")
    #expect(colorKeys("fill.0", w).map(\.frame) == [0, 15, 30])
    #expect(colorKeys("fill.0", w).first { $0.frame == 15 }?.value == orange)
    #expect(layer(w)?.shapes.first?.fill == staticFill)
    #expect(w.keyState(.fill) == .keyedHere)
}

@Test func recordingOffOnAStaticFillSetsTheStaticValue() {
    var w = ball()
    w.setCurrentFrame(20)
    w.setFill(hex: "FF9500")
    w.setStrokeWidth(3)
    #expect(layer(w)?.colorTracks.isEmpty == true)
    #expect(layer(w)?.tracks["strokeWidth.0"] == nil)
    #expect(layer(w)?.shapes.first?.fill == .solid(orange))
    #expect(layer(w)?.shapes.first?.stroke?.width == 3)
}

@Test(arguments: FlareWorkspace.PaintKey.allCases)
func keyStateFollowsThePlayhead(_ key: FlareWorkspace.PaintKey) {
    var w = ball()
    w.setStrokeWidth(2)
    #expect(w.keyState(key) == .notAnimated)
    #expect(w.paintKeyHelp(key) == nil)
    w.togglePaintKey(key)
    #expect(w.keyState(key) == .notAnimated)
    w.setCurrentFrame(30)
    w.togglePaintKey(key)
    #expect(w.keyState(key) == .keyedHere)
    w.setCurrentFrame(15)
    #expect(w.keyState(key) == .animated)
    w.setCurrentFrame(0)
    #expect(w.keyState(key) == .keyedHere)
}

@Test func togglingAtThePlayheadAddsAndRemovesAKey() {
    var w = ball()
    w.setFill(hex: "0000FF")
    w.togglePaintKey(.fill)
    #expect(colorKeys("fill.0", w).map(\.frame) == [0])
    #expect(colorKeys("fill.0", w).first?.value == blue)
    w.togglePaintKey(.fill)
    #expect(colorKeys("fill.0", w).isEmpty)
    w.togglePaintKey(.fill)
    w.setCurrentFrame(30)
    w.setFill(hex: "FF9500")
    w.togglePaintKey(.fill)
    #expect(colorKeys("fill.0", w).isEmpty)
    #expect(layer(w)?.shapes.first?.fill == .solid(blue))
    w.undo()
    #expect(colorKeys("fill.0", w).map(\.frame) == [0, 30])
}

@Test func paintKeysNeedExactlyOneShape() {
    var w = FlareWorkspace(services: .built)
    w.load(FlareFixtures.bounce)
    let before = w.document
    #expect(w.paintKeyHelp(.fill) == "Select one shape first.")
    #expect(w.keyState(.stroke) == .notAnimated)
    w.togglePaintKey(.strokeWidth)
    #expect(w.paintError == "Select one shape first.")
    #expect(w.document == before)
}
