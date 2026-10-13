// FlareSampleAnimationTests.swift: New Sample Animation opens the Ball
// document the easing editor's journey starts from: Ball keyed on x at 0, 24,
// 48 and on y at 0, 24, all linear, selected, with no undo history. Runs on
// Linux and macOS.
import FlareCore
import FlareModel
import Testing

struct FlareSampleAnimationTests {
    @Test func sampleSelectsBallWithFiveKeyframes() {
        var workspace = FlareWorkspace()
        workspace.newSampleAnimation()
        let ball = workspace.layers.first { $0.id == workspace.selectedLayerID }
        #expect(ball?.name == "Ball")
        #expect(workspace.layers.count == 1)
        #expect(ball?.shapes.count == 1)
        #expect(ball?.tracks.keys.sorted() == ["x", "y"])
        #expect(ball?.tracks["x"]?.map(\.frame) == [0, 24, 48])
        #expect(ball?.tracks["y"]?.map(\.frame) == [0, 24])
        #expect(ball?.tracks.values.joined().allSatisfy { $0.easing == .linear } == true)
        #expect(workspace.selectedScene?.durationFrames ?? 0 >= 48)
    }

    @Test func sampleHasNoUndoHistory() {
        var workspace = FlareWorkspace()
        workspace.newDocument()
        workspace.addLayer()
        #expect(workspace.canUndo)
        workspace.newSampleAnimation()
        #expect(workspace.canUndo == false)
        #expect(workspace.canRedo == false)
        #expect(workspace.layerError == nil)
    }

    @Test func samplePassesFlareFormatValidation() throws {
        var workspace = FlareWorkspace()
        workspace.newSampleAnimation()
        let document = try #require(workspace.document)
        try FlareFormat.validate(document)
    }
}
