// FlareNewDocumentTests.swift: layers-files LF-3 (FlareNewDocument.swift): presets, problems and refusals, a clean
// new document, and the spec's trip through its intent. Runs on `.built`, as a live launch does. Linux and macOS.
import FlareCore
import FlareModel
import Testing

@Suite struct FlareNewDocumentTests {
    @Test func verticalPresetGivesACleanDocument1080By1920At30FpsFor150Frames() throws {
        let spec = NewDocumentSpec(preset: .vertical)
        #expect(spec.problem == nil)
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument(spec)
        let scene = try #require(workspace.selectedScene)
        #expect(workspace.scenes.count == 1)
        #expect((scene.width, scene.height, scene.fps, scene.durationFrames) == (1080, 1920, 30, 150))
        #expect(scene.background == .white)
        #expect(!workspace.canUndo && !workspace.canRedo)
        #expect(!workspace.isDirty)
        #expect(workspace.layerError == nil)
    }

    @Test func customWidthZeroHasAProblemAndIsRefused() {
        var spec = NewDocumentSpec(preset: .web)
        spec.setSize(width: 0, height: 400)
        #expect(spec.preset == nil)
        #expect(spec.problem == "Width must be 1 to 16384 pt.")
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument(spec)
        #expect(workspace.document == nil)
        #expect(workspace.layerError == .refused("Width must be 1 to 16384 pt."))
        workspace.newDocument(NewDocumentSpec(preset: .square))
        let before = workspace.document
        spec.setSize(width: 1080, height: 20_000)
        workspace.newDocument(spec)
        #expect(workspace.document == before)
        #expect(workspace.layerError == .refused("Height must be 1 to 16384 pt."))
    }

    @Test(arguments: [
        (0, 48, "Frame rate must be 1 to 240 fps."),
        (24, 0, "Duration must be 1 to 100000 frames."),
    ])
    func badTimingOrBackgroundHasAProblem(fps: Int, frames: Int, problem: String) {
        var spec = NewDocumentSpec(preset: .hd1080)
        spec.fps = fps
        spec.durationFrames = frames
        #expect(spec.problem == problem)
        spec = NewDocumentSpec(preset: .hd1080)
        spec.background = FlareColor(r: 2, g: 0, b: 0)
        #expect(spec.problem == "Pick a valid background color.")
    }

    @Test func picksAPresetOrCustom() {
        var spec = NewDocumentSpec(preset: .hd1080)
        spec.pick(.vertical)
        #expect(spec == NewDocumentSpec(preset: .vertical))
        spec.pick(nil)
        #expect(spec.preset == nil)
        #expect((spec.width, spec.height, spec.fps) == (1080, 1920, 30))
    }

    @Test func roundTripsThroughItsIntent() throws {
        var spec = NewDocumentSpec(preset: .vertical)
        spec.background = FlareColor(r: 1, g: 0, b: 1)
        let intent = spec.intent
        #expect(intent == .create(preset: "Vertical 9:16", width: 1080, height: 1920, fps: 30, durationFrames: 150,
                                  backgroundHex: "#FF00FF"))
        let back = try #require(NewDocumentSpec(intent))
        #expect(back == spec)
        #expect(NewDocumentSpec(.create(preset: nil, width: 1, height: 1, fps: 24, durationFrames: 1,
                                        backgroundHex: "blue")) == nil)
        #expect(NewDocumentSpec(.new) == nil)
    }
}
