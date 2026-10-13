// FlareEasingTests.swift: FlareWorkspace as the easing editor's EasingEditing:
// segments from the selected layer's tracks, presets and handle moves as
// FlareCore SetKeyframeEasing steps, drag coalescing, clamping, exact undo and
// samples equal to FlareCore's curve. Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import Testing

private let xZeroTo24 = EasingSegment(property: "x", startFrame: 0, endFrame: 24)

/// Ball keyed on x at 0, 24, 48, on y at 0, 24 and on opacity at 12 only, plus
/// an empty layer "other"; Ball selected, loaded with no undo history.
private func workspace(locked: Bool = false) -> FlareWorkspace {
    let ball = Layer(
        id: "ball", name: "Ball",
        tracks: [
            "x": [0, 24, 48].map { Keyframe(frame: $0, value: Double($0)) },
            "y": [Keyframe(frame: 0, value: 0), Keyframe(frame: 24, value: 100)],
            "opacity": [Keyframe(frame: 12, value: 1)],
        ],
        isLocked: locked)
    var workspace = FlareWorkspace()
    workspace.load(Document(scenes: [Scene(id: "s", name: "S", layers: [Layer(id: "other", name: "Other"), ball])]))
    workspace.selectLayer("ball")
    return workspace
}

struct FlareEasingTests {
    @Test func segmentsListEveryKeyframeWithANext() {
        var workspace = workspace()
        #expect(workspace.easingSegments == [
            xZeroTo24,
            EasingSegment(property: "x", startFrame: 24, endFrame: 48),
            EasingSegment(property: "y", startFrame: 0, endFrame: 24),
        ])
        #expect(workspace.selectedEasingSegment == nil)
        #expect(workspace.currentEasing == nil)
        #expect(workspace.easingCurveSamples(count: 3).isEmpty)
        workspace.selectLayer("other")
        #expect(workspace.easingSegments.isEmpty)
    }

    @Test func selectingAnotherLayerClearsTheSegment() {
        var workspace = workspace()
        workspace.selectEasingSegment(EasingSegment(property: "x", startFrame: 0, endFrame: 48))
        #expect(workspace.selectedEasingSegment == nil)
        workspace.selectEasingSegment(xZeroTo24)
        #expect(workspace.selectedEasingSegment == xZeroTo24)
        #expect(workspace.currentEasingPreset == .linear)
        workspace.selectLayer("other")
        workspace.selectLayer("ball")
        #expect(workspace.selectedEasingSegment == nil)
        workspace.selectEasingSegment(xZeroTo24)
        workspace.newDocument()
        #expect(workspace.selectedEasingSegment == nil)
    }

    @Test func presetIsOneUndoStepNamedSetKeyframeEasing() {
        var workspace = workspace()
        workspace.selectEasingSegment(xZeroTo24)
        workspace.setEasingPreset(.easeIn)
        #expect(workspace.currentEasing == .cubicBezier(x1: 0.42, y1: 0, x2: 1, y2: 1))
        #expect(workspace.currentEasingPreset == .easeIn)
        #expect(workspace.document?.scenes.first?.layers.last?.tracks["x"]?.first?.easing == .easeIn)
        #expect(workspace.undoActionName == "Undo Set Keyframe Easing")
        workspace.undo()
        #expect(workspace.currentEasing == .linear)
        #expect(workspace.canUndo == false)
        #expect(workspace.redoActionName == "Redo Set Keyframe Easing")
    }

    @Test func handleXIsClampedAndYMayOvershoot() {
        var workspace = workspace()
        workspace.selectEasingSegment(xZeroTo24)
        workspace.moveEasingHandle(.first, to: Point(x: -0.5, y: 1.4))
        workspace.endEasingHandleDrag()
        workspace.moveEasingHandle(.second, to: Point(x: 1.7, y: -0.3))
        workspace.endEasingHandleDrag()
        #expect(workspace.currentEasing == .cubicBezier(x1: 0, y1: 1.4, x2: 1, y2: -0.3))
        workspace.moveEasingHandle(.first, to: Point(x: .nan, y: 0))
        workspace.moveEasingHandle(.second, to: Point(x: 0.5, y: .infinity))
        #expect(workspace.currentEasingHandles?.first == Point(x: 0, y: 1.4))
        #expect(workspace.currentEasingHandles?.second == Point(x: 1, y: -0.3))
        workspace.undo()
        workspace.undo()
        #expect(workspace.canUndo == false)
    }

    @Test func oneDragIsOneUndoStep() {
        var workspace = workspace()
        workspace.selectEasingSegment(xZeroTo24)
        for i in 1...10 { workspace.moveEasingHandle(.first, to: Point(x: Double(i) / 10, y: 0)) }
        workspace.endEasingHandleDrag()
        workspace.moveEasingHandle(.first, to: Point(x: 0.2, y: 0.2))
        workspace.endEasingHandleDrag()
        // A preset between two moves of the same handle ends the drag too.
        workspace.moveEasingHandle(.second, to: Point(x: 0.5, y: 0.5))
        workspace.setEasingPreset(.ease)
        workspace.moveEasingHandle(.second, to: Point(x: 0.6, y: 0.6))
        workspace.undo()
        #expect(workspace.currentEasing == .ease)
        workspace.undo()
        workspace.undo()
        workspace.undo()
        #expect(workspace.currentEasingHandles?.first == Point(x: 1, y: 0))
        workspace.undo()
        #expect(workspace.currentEasing == .linear)
        #expect(workspace.canUndo == false)
    }

    @Test func undoRestoresTheDocumentExactly() {
        var workspace = workspace()
        let before = workspace.document
        for segment in workspace.easingSegments {
            workspace.selectEasingSegment(segment)
            workspace.setEasingPreset(.easeOut)
            for i in 0..<5 { workspace.moveEasingHandle(.second, to: Point(x: 0.1 * Double(i), y: 1.3)) }
            workspace.endEasingHandleDrag()
            workspace.setEasingPreset(.hold)
        }
        #expect(workspace.document != before)
        var steps = 0
        while workspace.canUndo { workspace.undo(); steps += 1 }
        #expect(steps == 9)
        #expect(workspace.document == before)
        #expect(workspace.layerError == nil)
    }

    @Test(arguments: EasingPreset.allCases)
    func samplesMatchFlareCoreWithinOneBillionth(_ preset: EasingPreset) {
        var workspace = workspace()
        workspace.selectEasingSegment(xZeroTo24)
        workspace.setEasingPreset(preset)
        workspace.moveEasingHandle(.first, to: Point(x: 0.3, y: 1.2))
        guard let easing = workspace.currentEasing else { Issue.record("no easing"); return }
        let samples = workspace.easingCurveSamples(count: 1001)
        #expect(samples.count == 1001)
        #expect(samples.first == Point(x: 0, y: 0))
        #expect(samples.last == Point(x: 1, y: 1))
        let worst = samples.map { abs($0.y - easing.value(at: $0.x)) }.max() ?? 1
        #expect(worst <= 1e-9)
        #expect(workspace.easingCurveSamples(count: 1).isEmpty)
    }

    @Test func lockedLayerIsRefused() {
        var workspace = workspace(locked: true)
        workspace.selectEasingSegment(xZeroTo24)
        workspace.setEasingPreset(.easeIn)
        #expect(workspace.layerError == .command(.layerLocked("ball")))
        workspace.moveEasingHandle(.first, to: Point(x: 0.5, y: 0.5))
        #expect(workspace.layerError == .command(.layerLocked("ball")))
        #expect(workspace.currentEasing == .linear)
        #expect(workspace.canUndo == false)
    }
}
