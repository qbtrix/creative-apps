// HaloRenderRunTests.swift: MJ-CL2 (core-loop CL-1, on since CL-6; #1971).
// Every transition of Halo's render job through the kernel adapter
// (HaloRenderJob+Kernel onto SuiteKernel's ExportRun) on the `keyed` fixture
// ("Bounce", 1920 × 1080, 24 fps, 48 frames) with the fake services, plus a
// refused plan and a cancelled run's late outcome. Linux and macOS.
import HaloModel
import Testing

@Suite struct HaloRenderRunTests {
    private static let pngHalf = HaloRenderSettings(format: .pngSequence, halfSize: true)

    private static func keyed() throws -> HaloProject {
        HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
    }

    /// `keyed` with a half-size PNG sequence begun and started.
    private static func running() throws -> HaloProject {
        var project = try keyed()
        let begun = project.beginRender(pngHalf), started = project.startRender()
        #expect(begun && started != nil)
        return project
    }

    private static func done(_ project: HaloProject) -> Int? {
        guard case .running(_, let done, _) = project.renderRun else { return nil }
        return done
    }

    @Test func beginOpensEditingOnce() throws {
        var project = try Self.keyed()
        #expect(project.renderRun == .idle)
        let first = project.beginRender(Self.pngHalf)
        #expect(first && project.renderRun == .editing(Self.pngHalf))
        let again = project.beginRender(HaloRenderSettings(format: .movie))
        #expect(!again)
        #expect(project.renderRun == .editing(Self.pngHalf))
    }

    @Test func setRenderSettingsOnlyWhileEditing() throws {
        var project = try Self.keyed()
        let movie = HaloRenderSettings(format: .movie)
        project.setRenderSettings(movie)
        #expect(project.renderRun == .idle)
        _ = project.beginRender(Self.pngHalf)
        project.setRenderSettings(movie)
        #expect(project.renderRun == .editing(movie))
    }

    @Test func startRunsThePlan() throws {
        var project = try Self.keyed()
        _ = project.beginRender(Self.pngHalf)
        let result = project.startRender()
        let started = try #require(result)
        #expect(started.plan.frames == Array(0..<48))
        #expect(started.plan.width == 960 && started.plan.height == 540)
        #expect(started.composition.name == "Bounce")
        #expect(project.renderRun == .running(Self.pngHalf, done: 0, total: 48))
    }

    @Test func progressShowsAtOnce() throws {
        let project = try Self.running()
        #expect(project.renderProgressText == "Frame 0 of 48")
    }

    @Test func progressNeverBack() throws {
        var project = try Self.running()
        project.renderProgressed(done: 12)
        #expect(Self.done(project) == 12)
        project.renderProgressed(done: 11)
        #expect(Self.done(project) == 12)
        #expect(project.renderProgressText == "Frame 12 of 48")
        project.renderProgressed(done: 99)
        #expect(Self.done(project) == 48)
    }

    @Test func progressIgnoredUnlessRunning() throws {
        var project = try Self.keyed()
        project.renderProgressed(done: 5)
        #expect(project.renderRun == .idle)
        _ = project.beginRender(Self.pngHalf)
        project.renderProgressed(done: 5)
        #expect(project.renderRun == .editing(Self.pngHalf))
        #expect(project.renderProgressText == nil)
    }

    @Test func secondStartRefused() throws {
        var project = try Self.running()
        project.renderProgressed(done: 3)
        let second = project.startRender()
        #expect(second == nil)
        #expect(project.renderRun == .running(Self.pngHalf, done: 3, total: 48))
    }

    @Test func beginRefusedWhileRunning() throws {
        var project = try Self.running()
        let begun = project.beginRender(HaloRenderSettings(format: .movie))
        #expect(!begun)
        #expect(project.renderRun == .running(Self.pngHalf, done: 0, total: 48))
    }

    @Test func finishedNamesEveryFile() throws {
        var project = try Self.running()
        project.renderProgressed(done: 48)
        project.endRender(.finished(frames: 48))
        let names = (1...48).map { "Bounce_" + String(repeating: "0", count: 4 - "\($0)".count) + "\($0).png" }
        #expect(project.renderRun == .finished(Self.pngHalf, names))
        #expect(project.renderOutcomeText == "Rendered 48 frames.")
        #expect(project.renderProgressText == nil)
    }

    @Test func failedSaysWhereItStopped() throws {
        var project = try Self.running()
        project.endRender(.failed(frame: 5, message: "Disk full"))
        #expect(project.renderRun == .failed(Self.pngHalf, "Render stopped at frame 5: Disk full."))
        #expect(project.renderOutcomeText == "Render stopped at frame 5: Disk full.")
    }

    @Test func cancelReturnsToIdle() throws {
        var project = try Self.running()
        project.renderProgressed(done: 12)
        project.endRender(.cancelled(frames: 12))
        #expect(project.renderRun == .idle)
        #expect(project.renderJob == nil)
    }

    @Test func cancelFromEditingOrRunningGoesIdle() throws {
        var editing = try Self.keyed()
        _ = editing.beginRender(Self.pngHalf)
        editing.cancelRender()
        #expect(editing.renderRun == .idle)
        var running = try Self.running()
        running.cancelRender()
        #expect(running.renderRun == .idle && running.renderJob == nil)
    }

    @Test func dismissClosesFinishedAndFailed() throws {
        var finished = try Self.running()
        finished.endRender(.finished(frames: 48))
        finished.dismissRender()
        #expect(finished.renderRun == .idle)
        var failed = try Self.running()
        failed.endRender(.failed(frame: 5, message: "Disk full"))
        failed.dismissRender()
        #expect(failed.renderRun == .idle)
    }

    @Test func dismissLeavesARunningRender() throws {
        var project = try Self.running()
        project.dismissRender()
        #expect(project.renderRun == .running(Self.pngHalf, done: 0, total: 48))
    }

    @Test func refusedPlanFailsInWords() throws {
        var services = HaloServices.fake
        services.compositionRendering = RefusingRendering()
        var project = HaloProject(services: services, document: try #require(HaloFixtures.project("keyed")))
        _ = project.beginRender(Self.pngHalf)
        let started = project.startRender()
        #expect(started == nil)
        #expect(project.renderRun == .failed(Self.pngHalf, "Rendering isn't built yet."))
        #expect(project.renderJob?.plan == nil && project.renderProgressText == nil)
        project.dismissRender()
        #expect(project.renderJob == nil)
    }

    @Test func aCancelledRunIgnoresItsLateOutcome() throws {
        var project = try Self.running()
        project.cancelRender()
        project.endRender(.cancelled(frames: 3))
        project.endRender(.finished(frames: 48))
        #expect(project.renderRun == .idle && project.renderJob == nil)
    }

    @Test func noCompositionBeginsNothing() {
        var project = HaloProject(services: .fake)
        let begun = project.beginRender(Self.pngHalf), started = project.startRender()
        #expect(!begun && started == nil)
        #expect(project.renderRun == .idle)
    }
}

/// A composition renderer whose plan is always refused.
private struct RefusingRendering: CompositionRendering {
    var unavailableHelp: String? { nil }
    func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        throw HaloEditError.notBuilt("Rendering")
    }
    func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, text: (any TextRasterizing)?,
        into sink: inout some RenderSink, isCancelled: () -> Bool
    ) -> HaloRenderOutcome { .failed(frame: 0, message: "unused") }
}
