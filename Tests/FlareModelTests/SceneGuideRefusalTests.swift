// SceneGuideRefusalTests.swift: a refused scene or guide edit says what is wrong with the field in a plain sentence,
// never "The layer could not be changed (invalidFPS(0))." (#571), and leaves the document and undo stack alone.
import FlareCore
@testable import FlareModel
import Testing

private func bounce() -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.load(FlareFixtures.bounce)
    return workspace
}

private let black = FlareColor(r: 0, g: 0, b: 0)

@Test(arguments: [
    (0, 60, "Frame rate must be at least 1 fps."),
    (-5, 60, "Frame rate must be at least 1 fps."),
    (24, -1, "Length can't be negative."),
])
func sceneTimingRefusalsReadAsSentences(fps: Int, frames: Int, message: String) {
    var w = bounce()
    w.setSceneTiming(fps: fps, durationFrames: frames)
    #expect(w.layerError?.message == message)
    #expect(w.document == FlareFixtures.bounce && !w.canUndo)
}

@Test(arguments: [
    (0.0, -5.0, black, "Canvas size must be greater than 0."),
    (.nan, 480, black, "Canvas size must be greater than 0."),
    (640, .infinity, black, "Canvas size must be greater than 0."),
    (640, 480, FlareColor(r: .nan, g: 0, b: 0), "Pick a valid background color."),
])
func sceneCanvasRefusalsReadAsSentences(width: Double, height: Double, background: FlareColor, message: String) {
    var w = bounce()
    w.setSceneCanvas(width: width, height: height, background: background)
    #expect(w.layerError?.message == message)
    #expect(w.document == FlareFixtures.bounce && !w.canUndo)
}

@Test func guideRefusalsReadAsSentences() {
    var w = bounce()
    w.addGuide(.vertical, at: .nan)
    #expect(w.layerError?.message == "A guide needs a position on the canvas.")
    #expect(w.document == FlareFixtures.bounce && !w.canUndo)
    w.addGuide(.horizontal, at: 100)
    let added = w.document
    w.moveGuide(at: 0, to: -.infinity, dragStart: 100)
    #expect(w.layerError?.message == "A guide needs a position on the canvas.")
    #expect(w.document == added)
}

@Test func timingCantCutOffAFrameLabel() {
    var document = FlareFixtures.bounce
    guard !document.scenes.isEmpty else { return #expect(Bool(false)) }
    document.scenes[0].labels = ["Hit": 40]
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    w.setSceneTiming(fps: 24, durationFrames: 30)
    #expect(w.layerError?.message == "Length must reach frame 40, where the label \u{201C}Hit\u{201D} sits.")
    #expect(w.document == document && !w.canUndo)
}

@Test func noSceneOrGuideRefusalShowsLayerDebugText() {
    var w = bounce()
    let edits: [(inout FlareWorkspace) -> Void] = [
        { $0.setSceneTiming(fps: 0, durationFrames: 0) },
        { $0.setSceneCanvas(width: 0, height: -5, background: black) },
        { $0.addGuide(.vertical, at: .nan) },
    ]
    for edit in edits {
        edit(&w)
        #expect(w.layerError.map { !$0.message.contains("layer") && !$0.message.contains("(") } == true)
    }
}
