// FlareVideoExportTests.swift: MJ-FV, the Model walk of Flare's MP4 and GIF export
// (docs/blueprints/flare/features/export-pack.md). FV-1: the formats are listed with their options (the shared size,
// the scene's frame rate, loop on), not refused since FV-4, while SVG, Lottie and PNG still export. The plan
// tests are FV-3's: every frame of the scene at the rate with FrameClock's times and GIF delays, ExportRules' size
// (even for MP4), GIF without the background fill and looping, and RJ-F07's and RJ-F08's plan halves.
import FlareCore
@testable import FlareModel
import Foundation
import SuiteKernel
import SuiteModel
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

    /// FV-4: no longer refused; the sheet leaves them out until FV-2, and they write through `writeVideo`, not `export`.
    @Test(arguments: [(ExportFormat.mp4, "MP4 joins the Export sheet with FV-2."), (.gif, "GIF joins the Export sheet with FV-2.")])
    func exportingStartsAndWritesThroughWriteVideo(format: ExportFormat, reason: String) async throws {
        var w = bounce()
        _ = w.openExport(); w.setExportFormat(format)
        #expect(format.unbuiltReason == reason)
        #expect(w.exportProblem == nil && w.exportFileCount == 1)
        let o = try #require(w.exportingOptions), document = try #require(w.document)
        let started = w.startExport()
        #expect(started)
        await #expect(throws: ExportOptionRefusal.self) {
            try await LiveExportAdapter(stage: FakeStage()).export(document, options: o, rasterizer: FakeRasterizer()) { _ in }
        }
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

    // FV-3: the frame plan (rule 20: each frame's time and GIF delay are SuiteModel's FrameClock, the size
    // ExportRules'). FV-4 streams the planned frames into the shared writers.

    @Test(.tags(.everyFrame)) func aTwoSecondSceneAt30FPSPlans60Frames() throws {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(.gif)
        let plan = try w.exportVideoPlan()
        #expect(plan.fps == 30 && plan.frames.count == 60)
        #expect(plan.frames.map(\.index) == Array(0..<60))
        #expect(plan.frames.map(\.sceneFrame) == (0..<60).map(Double.init))
        let clock = try FrameClock(fps: 30)
        #expect(plan.frames.map(\.seconds) == (0..<60).map(clock.seconds(of:)))
        #expect(plan.frames.last?.seconds == 59.0 / 30)
        w.setExportFrameRate(15)
        let half = try w.exportVideoPlan()
        #expect(half.fps == 15 && half.frames.count == 30 && half.frames.last?.sceneFrame == 58)
    }

    @Test(.tags(.mp4IsEven)) func mp4At1081WidePlans1080() throws {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(.mp4)
        w.setExportSize(.pixels(width: 1081, height: 1081, stretch: true))
        let mp4 = try w.exportVideoPlan()
        #expect(mp4.width == 1080 && mp4.height == 1080)
        #expect(mp4.movie == MovieSettings(width: 1080, height: 1080, fps: 30, codec: .h264, quality: 0.9))
        #expect(mp4.animatedImage == nil)
        w.setExportFormat(.gif)
        let gif = try w.exportVideoPlan()
        #expect(gif.width == 1081 && gif.height == 1081, "a GIF has no even rule")
    }

    @Test(.tags(.gifKeepsAlpha)) func gifFramesCarryAlphaAndMP4IsOpaque() throws {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(.gif)
        let scene = try #require(w.selectedScene)
        let gif = try w.exportVideoPlan()
        #expect(!gif.fillsBackground && gif.scene(scene).background.a == 0)
        #expect(gif.scene(scene).layers == scene.layers)
        w.setExportFormat(.mp4)
        var clear = scene; clear.background.a = 0
        let mp4 = try w.exportVideoPlan()
        #expect(mp4.fillsBackground && mp4.scene(clear).background.a == 1)
        #expect(mp4.scene(clear).background.r == scene.background.r)
    }

    @Test(.tags(.everyFrame)) func gifDelaysSumTo200CentisecondsAndLoopForever() throws {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(.gif)
        let gif = try w.exportVideoPlan()
        #expect(gif.frames.map(\.delay).reduce(0, +) == 200)
        #expect(gif.frames.prefix(3).map(\.delay) == [3, 4, 3])
        #expect(gif.animatedImage == AnimatedImageSettings(width: 550, height: 400, fps: 30, format: .gif, loopCount: 0))
        #expect(gif.movie == nil)
        w.setExportLoop(false)
        #expect(try w.exportVideoPlan().animatedImage?.loopCount == 1)
    }

    @Test func onlyMP4AndGIFPlanFrames() throws {
        var w = bounce(); _ = w.openExport()
        #expect(throws: ExportOptionRefusal.self) { try w.exportVideoPlan() }
        w.setExportFormat(.gif); w.setExportSize(.longEdge(0))
        #expect(throws: (any Error).self) { try w.exportVideoPlan() }
    }

    /// RJ-F07's and RJ-F08's plan halves: each job's own options, read as the run reads them, plan its file.
    @Test(.tags(.everyFrame, .gifKeepsAlpha, .mp4IsEven), arguments: [
        ("slack-gif", "spinner.flare", 480, 480, 24, 100),
        ("social-mp4", "bounce.flare", 1920, 1080, 60, 200),
    ])
    func theRealJobsPlanHalf(job: String, input: String, width: Int, height: Int, frames: Int, centiseconds: Int) throws {
        struct Job: Decodable { var output: Output }
        struct Output: Decodable { var format: String; var options: JSONValue }
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RealJobs/flare/\(job)")
        let script = try JSONDecoder().decode(Job.self, from: Data(contentsOf: folder.appendingPathComponent("\(job).jobs.json")))
        let o = try SuiteExportOptions(json: script.output.options, defaults: SuiteExportOptions(format: script.output.format))
        let format = try #require(ExportFormat(rawValue: script.output.format))
        let data = try Data(contentsOf: folder.appendingPathComponent("input/\(input)"))
        let w = try FlareHeadless.open(data, name: input).workspace
        let scene = try #require(w.selectedScene)
        let options = ExportOptions(format: format, sceneID: scene.id, frames: 0...(scene.durationFrames - 1),
                                    size: o.size, fps: o.fps, loop: o.loop)
        let plan = try FlareVideoPlan.plan(scene, options: options)
        #expect(plan.width == width && plan.height == height && plan.frames.count == frames)
        #expect(plan.frames.map(\.delay).reduce(0, +) == centiseconds)
        if format == .gif {
            #expect(plan.animatedImage?.loopCount == 0 && scene.background.a == 0 && plan.scene(scene).background.a == 0)
        } else {
            #expect(plan.movie?.codec == .h264 && plan.scene(scene).background.a == 1 && plan.fps == 30)
        }
    }
}

extension Tag {
    @Tag static var everyFrame: Self
    @Tag static var gifKeepsAlpha: Self
    @Tag static var mp4IsEven: Self
}
