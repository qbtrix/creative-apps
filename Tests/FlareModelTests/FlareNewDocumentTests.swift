// FlareNewDocumentTests.swift: layers-files LF-3 (FlareNewDocument.swift): presets, problems and refusals, a clean
// new document, and the spec's trip through its intent. Runs on `.built`, as a live launch does. Linux and macOS.
// FR-10b: the rate is an exact `FrameRate` from the sheet to the scene, the inspector's timing intent and playback.
import FlareCore
import FlareModel
import SuiteKernel
import Testing

/// 23.976 from the kernel's list, never a typed literal.
private let ntsc = FrameRate.common.first { $0.numerator == 24000 && $0.denominator == 1001 } ?? FrameRate(whole: 0)

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
        #expect(spec.problem == "Width must be 1 to 16384 px.")
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument(spec)
        #expect(workspace.document == nil)
        #expect(workspace.layerError == .refused("Width must be 1 to 16384 px."))
        workspace.newDocument(NewDocumentSpec(preset: .square))
        let before = workspace.document
        spec.setSize(width: 1080, height: 20_000)
        workspace.newDocument(spec)
        #expect(workspace.document == before)
        #expect(workspace.layerError == .refused("Height must be 1 to 16384 px."))
    }

    @Test(arguments: [
        (0, 48, "Frame rate must be 1 to 240 fps."),
        (24, 0, "Duration must be 1 to 100000 frames."),
    ])
    func badTimingOrBackgroundHasAProblem(fps: Int, frames: Int, problem: String) {
        var spec = NewDocumentSpec(preset: .hd1080)
        spec.fps = FrameRate(whole: fps)
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
        #expect((spec.width, spec.height, spec.fps) == (1080, 1920, FrameRate(whole: 30)))
    }

    @Test func roundTripsThroughItsIntent() throws {
        var spec = NewDocumentSpec(preset: .vertical)
        spec.background = FlareColor(r: 1, g: 0, b: 1)
        let intent = spec.intent
        #expect(intent == .create(preset: "Vertical 9:16", width: 1080, height: 1920, fps: FrameRate(whole: 30),
                                  durationFrames: 150, backgroundHex: "#FF00FF"))
        let back = try #require(NewDocumentSpec(intent))
        #expect(back == spec)
        #expect(NewDocumentSpec(.create(preset: nil, width: 1, height: 1, fps: FrameRate(whole: 24), durationFrames: 1,
                                        backgroundHex: "blue")) == nil)
        #expect(NewDocumentSpec(.new) == nil)
    }

    @Test func an2398SpecMakesAnExact2398Scene() throws {
        var spec = NewDocumentSpec(preset: .web)
        spec.fps = ntsc
        #expect(try #require(NewDocumentSpec(spec.intent)).fps == ntsc)
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument(spec)
        let scene = try #require(workspace.selectedScene)
        #expect((scene.frameRate, scene.fps) == (ntsc, 24))
        #expect(workspace.statusPills(measuredFPS: nil).fps == "23.976 fps")
    }

    @Test func theInspectorsTimingIntentSetsTheExactRateInOneStep() throws {
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument(NewDocumentSpec(preset: .web))
        let frames = try #require(workspace.selectedScene).durationFrames
        workspace.setSceneTiming(ntsc, durationFrames: frames)
        #expect(workspace.layerError == nil)
        #expect(workspace.selectedScene?.frameRate == ntsc)
        #expect(workspace.selectedScene?.durationFrames == frames)
        workspace.setSceneTiming(ntsc, durationFrames: 96)
        #expect(workspace.selectedScene?.frameRate == ntsc)
        #expect(workspace.selectedScene?.durationFrames == 96)
        workspace.undo()
        workspace.undo()
        #expect(workspace.selectedScene?.frameRate == FrameRate(whole: 24))
        #expect(workspace.canUndo == false)
    }

    @Test(arguments: [(FrameRate(whole: 24), 24), (ntsc, 23)])
    func playbackTicksByTheExactRate(rate: FrameRate, frameAfterASecond: Int) {
        var spec = NewDocumentSpec(preset: .web)
        (spec.fps, spec.durationFrames) = (rate, 96)
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument(spec)
        workspace.play()
        workspace.advance(elapsed: 1)
        #expect(workspace.currentFrame == frameAfterASecond)
    }

    @Test func aRunningPlayKeepsItsFrameFrom24To2398() {
        var spec = NewDocumentSpec(preset: .web)
        spec.durationFrames = 96
        var workspace = FlareWorkspace(services: .built)
        workspace.newDocument(spec)
        workspace.setCurrentFrame(47)
        workspace.play()
        workspace.setSceneTiming(ntsc, durationFrames: 96)
        #expect(workspace.playClock == ntsc.seconds(ofFrame: 47))
        workspace.advance(elapsed: 0.000_1)
        #expect(workspace.currentFrame == 47)
    }
}
