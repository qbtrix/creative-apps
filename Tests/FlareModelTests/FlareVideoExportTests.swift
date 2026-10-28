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

    /// FV-2: the sheet lists them, and they write through `writeVideo`, not `export`.
    @Test(arguments: [ExportFormat.mp4, .gif])
    func exportingStartsAndWritesThroughWriteVideo(format: ExportFormat) async throws {
        var w = bounce()
        _ = w.openExport(); w.setExportFormat(format)
        #expect(format.unbuiltReason == nil && format.writesVideo)
        #expect(w.exportProblem == nil && w.exportFileCount == 1)
        let o = try #require(w.exportingOptions), document = try #require(w.document)
        let started = w.startExport()
        #expect(started)
        await #expect(throws: ExportOptionRefusal.self) {
            try await LiveExportAdapter(stage: FakeStage()).export(document, options: o, rasterizer: FakeRasterizer()) { _ in }
        }
    }

    /// FV-2: the sheet's Size row reads the shared size's scale for MP4 and GIF and the run's scale otherwise, and a
    /// frame rate under 1 refuses Export with its reason.
    @Test func theSheetReadsTheSharedSizeAndRefusesARateUnder1() throws {
        var w = bounce(); _ = w.openExport()
        #expect(!ExportFormat.svgFrame.writesVideo && !ExportFormat.lottie.writesVideo && !ExportFormat.pngSequence.writesVideo)
        w.setExportScale(2)
        #expect(w.exportingOptions?.sheetScale == 2)
        w.setExportFormat(.gif)
        #expect(w.exportingOptions?.sheetScale == 1)
        w.setExportSize(.scale(0.5))
        #expect(w.exportingOptions?.sheetScale == 0.5 && w.exportProblem == nil)
        w.setExportSize(.longEdge(480))
        #expect(w.exportingOptions?.sheetScale == 1)
        w.setExportFrameRate(0)
        #expect(w.exportProblem == "The frame rate must be 1 or more." && w.exportFileCount == 0)
        w.setExportFrameRate(12)
        #expect(w.exportProblem == nil && w.exportFrameRate == 12)
    }

    /// #5012: the sheet reads the planned pixels, frames and length live, even for MP4 and as given for GIF.
    @Test(.tags(.mp4IsEven)) func theSheetReadsThePlannedPixelsFramesAndLength() throws {
        var w = bounce(); _ = w.openExport()
        #expect(w.exportPixelSize == nil && w.exportVideoSummary == nil, "PNG has no video readout")
        w.setExportFormat(.mp4); w.setExportSize(.scale(0.5))
        #expect(w.exportPixelSize?.width == 274 && w.exportPixelSize?.height == 200, "275 rounds down to even")
        #expect(w.exportVideoSummary == "274 × 200 px · 60 frames · 2.0 s")
        w.setExportSize(.pixels(width: 1081, height: 721, stretch: true)); w.setExportFrameRate(24)
        #expect(w.exportVideoSummary == "1080 × 720 px · 48 frames · 2.0 s")
        w.setExportFormat(.gif); w.setExportFrameRate(1)
        #expect(w.exportVideoSummary == "1081 × 721 px · 2 frames · 2.0 s")
        w.setExportSize(.longEdge(0))
        #expect(w.exportVideoSummary == nil && w.exportPixelSize == nil)
    }

    /// #5014: the Size row's modes carry a whole size: Long edge and Pixels start from the current pixels.
    @Test func theSizeRowSwitchesBetweenScaleLongEdgeAndPixels() throws {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(.gif)
        #expect(w.exportingOptions?.sizeMode == .scale)
        #expect(w.exportSize(.longEdge) == .longEdge(550))
        #expect(w.exportSize(.pixels) == .pixels(width: 550, height: 400, stretch: true))
        w.setExportSize(w.exportSize(.longEdge))
        #expect(w.exportingOptions?.sizeMode == .longEdge)
        let intent = FlareIntent.export(.setSize(.longEdge(480)))
        guard case .export(.setSize(let size)) = intent else { Issue.record("not a size"); return }
        w.setExportSize(size)
        #expect(w.exportingOptions?.size == .longEdge(480) && w.exportPixelSize?.width == 480)
        w.setExportSize(w.exportSize(.pixels))
        #expect(w.exportingOptions?.size == .pixels(width: 480, height: 349, stretch: true))
        #expect(w.exportingOptions?.sizeMode == .pixels && w.exportSize(.scale) == .scale(1))
        #expect(ExportSizeMode.allCases.map(\.title) == ["Scale", "Long edge", "Pixels"])
    }

    /// #5015: the file is named once, by the Model, and the writer's own "already exists" reads as the sheet's.
    @Test func theVideoFileIsNamedByTheModelAndATakenNameReadsAsAlreadyThere() throws {
        var w = bounce(); _ = w.openExport()
        #expect(w.exportVideoFileName == nil)
        w.setExportFormat(.gif)
        #expect(w.exportVideoFileName == "scene-1.gif")
        w.setExportFormat(.mp4)
        #expect(w.exportVideoFileName == "scene-1.mp4")
        let taken = FlareWorkspace.videoWriteError(
            SuiteError.notAvailable("A file named scene-1.mp4 already exists."), name: "scene-1.mp4", folder: "Exports")
        #expect(taken as? ExportWriteRefusal == .alreadyThere(name: "scene-1.mp4", folder: "Exports"))
        #expect(FlareWorkspace.exportMessage(taken) == "scene-1.mp4 is already in Exports. Choose another folder.")
        let other = FlareWorkspace.videoWriteError(SuiteError.notAvailable("No encoder."), name: "scene-1.mp4", folder: "Exports")
        #expect(other as? SuiteError == .notAvailable("No encoder.") && FlareWorkspace.exportMessage(other) == "No encoder.")
    }

    /// #5017: an exporter that can't write MP4 or GIF refuses Export with its reason instead of writing blank frames,
    /// while SVG, Lottie and PNG still start. The live one draws real frames (StageRasterizer's `frame`), so it has none.
    @Test(arguments: [ExportFormat.mp4, .gif])
    func anExporterWithoutVideoRefusesItWithItsReason(format: ExportFormat) throws {
        #expect(LiveExportAdapter(stage: FakeStage()).videoUnbuiltReason == nil)
        var document = FlareFixtures.bounce
        document.scenes[0].fps = 30; document.scenes[0].durationFrames = 60
        var services = FlareServices.fake(); services.export = NoVideoExport()
        var w = FlareWorkspace(services: services); w.load(document); _ = w.openExport()
        #expect(w.exportProblem == nil)
        w.setExportFormat(format)
        #expect(w.exportProblem == NoVideoExport.reason && w.exportFileCount == 0)
        let started = w.startExport()
        #expect(!started)
    }

    /// #5018: a rate of exactly 1 exports, and only MP4 and GIF read the rate.
    @Test func aRateOf1ExportsAndOnlyVideoReadsTheRate() throws {
        var w = bounce(); _ = w.openExport()
        w.setExportFrameRate(0)
        #expect(w.exportProblem == nil, "PNG ignores the video rate")
        w.setExportFormat(.gif)
        #expect(w.exportProblem == "The frame rate must be 1 or more.")
        w.setExportFrameRate(1)
        #expect(w.exportProblem == nil && w.exportFileCount == 1)
    }

    /// Packet-Review 2: a GIF runs at 1 to 50 frames a second (MediaRules), so the sheet refuses 51 before Export
    /// instead of the writer failing mid-run; MP4 still takes 60.
    @Test func aGIFAbove50FramesASecondIsRefusedButMP4IsNot() throws {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(.gif)
        w.setExportFrameRate(50)
        #expect(w.exportProblem == nil)
        w.setExportFrameRate(51)
        #expect(w.exportProblem == "A GIF runs at 1 to 50 frames a second." && w.exportFileCount == 0)
        w.setExportFormat(.mp4)
        #expect(w.exportProblem == nil, "MP4 takes up to 120")
        w.setExportFrameRate(60)
        #expect(w.exportProblem == nil)
    }

    /// FV-5: an MP4 or GIF run counts the plan's frames, so the sheet's bar moves through one file; a file run
    /// still counts files.
    @Test(arguments: [ExportFormat.mp4, .gif])
    func aVideoRunCountsItsFrames(format: ExportFormat) throws {
        var w = bounce(); _ = w.openExport(); w.setExportFormat(format)
        let started = w.startExport()
        let o = try #require(w.exportingOptions)
        #expect(started && w.exportState == .running(o, done: 0, total: 60))
        w.exportProgressed(0.5)
        #expect(w.exportState == .running(o, done: 30, total: 60))
        var half = bounce(); _ = half.openExport(); half.setExportFormat(format); half.setExportFrameRate(15)
        let halfStarted = half.startExport()
        #expect(halfStarted && half.exportState == .running(try #require(half.exportingOptions), done: 0, total: 30))
        var png = bounce(); _ = png.openExport(); png.setExportFormat(.pngSequence); png.setExportStep(2)
        let pngStarted = png.startExport()
        #expect(pngStarted && png.exportState == .running(try #require(png.exportingOptions), done: 0, total: 30))
        var svg = bounce(); _ = svg.openExport()
        let svgStarted = svg.startExport()
        #expect(svgStarted && svg.exportState == .running(try #require(svg.exportingOptions), done: 0, total: 1))
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

/// FakeExport, but it can't write MP4 or GIF.
private struct NoVideoExport: Exporting {
    static let reason = "This exporter can't write video."
    let base = FakeExport(frameDelay: .zero)
    var videoUnbuiltReason: String? { Self.reason }
    func warnings(_ document: Document, options: ExportOptions) -> [String] { base.warnings(document, options: options) }
    func export(_ document: Document, options: ExportOptions, rasterizer: any FrameRasterizing,
                progress: @Sendable (Double) -> Void) async throws -> ExportResult {
        try await base.export(document, options: options, rasterizer: rasterizer, progress: progress)
    }
    func writeVideo(_ document: Document, sceneID: String, plan: FlareVideoPlan, to path: String,
                    media: any MediaEncoding, rasterizer: any FrameRasterizing,
                    progress: @Sendable (Double) -> Void) async throws -> String {
        try await base.writeVideo(document, sceneID: sceneID, plan: plan, to: path, media: media,
                                  rasterizer: rasterizer, progress: progress)
    }
}
