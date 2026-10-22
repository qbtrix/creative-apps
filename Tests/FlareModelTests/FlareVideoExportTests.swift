// FlareVideoExportTests.swift: MJ-FV, the Model walk of Flare's MP4 and GIF export
// (docs/blueprints/flare/features/export-pack.md). FV-1: the formats are listed with their options (the shared size,
// the scene's frame rate, loop on) and refused with their reason, while SVG, Lottie and PNG still export. The plan
// tests are FV-3's and wait on it (rule 20: the frames' times are shell-media's FrameClock, the size ExportRules').
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

private func showcase() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake()); w.load(FlareFixtures.showcase); return w
}

/// `Bounce.flare` as the journey opens it: 2 s at 30 fps.
private func bounce() -> FlareWorkspace {
    var document = FlareFixtures.bounce
    document.scenes[0].fps = 30; document.scenes[0].durationFrames = 60
    var w = FlareWorkspace(services: .fake()); w.load(document); return w
}

struct FlareVideoExportTests {
    @Test func mp4AndGIFAreListedWithTheSharedSizeTheScenesRateAndLoop() throws {
        #expect(ExportFormat.allCases.contains(.mp4) && ExportFormat.allCases.contains(.gif))
        var w = bounce()
        let opened = w.openExport()
        #expect(opened)
        w.setExportFormat(.gif)
        let gif = try #require(w.exportingOptions)
        #expect(gif.format == .gif && gif.size == .scale(1) && gif.loop)
        #expect(gif.fps == nil && w.exportFrameRate == 30)
        w.setExportSize(.longEdge(480)); w.setExportLoop(false); w.setExportFrameRate(15)
        #expect(w.exportingOptions?.size == .longEdge(480) && w.exportingOptions?.loop == false)
        #expect(w.exportFrameRate == 15)
    }

    @Test(arguments: [(ExportFormat.mp4, "MP4 lands with FV-3."), (.gif, "GIF lands with FV-3.")])
    func exportingIsRefusedWithItsReason(format: ExportFormat, reason: String) async throws {
        var w = bounce()
        _ = w.openExport(); w.setExportFormat(format)
        #expect(format.unbuiltReason == reason)
        #expect(w.exportProblem == reason && w.exportFileCount == 0)
        let started = w.startExport()
        #expect(!started && w.exportingOptions?.format == format)
        let o = try #require(w.exportingOptions), document = try #require(w.document)
        await #expect(throws: NotBuilt(reason: reason)) {
            try await LiveExportAdapter(stage: FakeStage()).export(document, options: o, rasterizer: FakeRasterizer()) { _ in }
        }
        #expect(FlareWorkspace.exportMessage(NotBuilt(reason: reason)) == reason)
    }

    @Test func svgLottieAndPNGStillExport() async throws {
        #expect(ExportFormat.svgFrame.unbuiltReason == nil && ExportFormat.lottie.unbuiltReason == nil)
        #expect(ExportFormat.pngSequence.unbuiltReason == nil)
        var w = showcase()
        _ = w.openExport()
        #expect(w.exportProblem == nil && w.exportFileCount == 1)
        let started = w.startExport()
        #expect(started)
        let document = try #require(w.document), adapter = LiveExportAdapter(stage: FakeStage())
        let png = ExportOptions(format: .pngSequence, sceneID: "scene-1", frames: 0...2)
        let svg = ExportOptions(format: .svgFrame, sceneID: "scene-1", frames: 0...0)
        #expect(try await adapter.export(document, options: png, rasterizer: FakeRasterizer()) { _ in }.files.count == 3)
        #expect(try await adapter.export(document, options: svg, rasterizer: FakeRasterizer()) { _ in }.files.count == 1)
    }

    // FV-3 turns these on: they read the frame plan, which FlareExport+Kernel.swift gains then.

    @Test(.disabled("waits on FV-3")) func aTwoSecondSceneAt30FPSPlans60Frames() {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(.gif)
        #expect(w.exportFrameRate == 30 && w.selectedScene?.durationFrames == 60)
        Issue.record("FV-3: the GIF plan lists 60 frames, 0 to 59, each at FrameClock's time")
    }

    @Test(.disabled("waits on FV-3")) func mp4At1081WidePlans1080() {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(.mp4)
        w.setExportSize(.pixels(width: 1081, height: 1081, stretch: false))
        #expect(w.exportingOptions?.size == .pixels(width: 1081, height: 1081, stretch: false))
        Issue.record("FV-3: the MP4 plan's size is 1080 x 1080 (ExportRules.pixels(evenSize: true))")
    }

    @Test(.disabled("waits on FV-3")) func gifDelaysSumTo200Centiseconds() {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(.gif)
        #expect(w.exportingOptions?.loop == true)
        Issue.record("FV-3: the GIF plan's frame delays sum to 200 cs, within 1 cs")
    }
}
