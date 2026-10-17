// HaloRenderJobTests.swift: the render job behind File > Render… (RO-3, #429)
// on the `keyed` fixture ("Bounce", 1920 × 1080, 24 fps, 48 frames) with the
// fake services: the sheet, the output name and summary, progress, Cancel and
// every outcome's text. Runs on Linux and macOS.
import HaloModel
import Testing

private let pngHalf = HaloRenderSettings(format: .pngSequence, halfSize: true)
private let movieFull = HaloRenderSettings(format: .movie)

private func keyed(_ services: HaloServices = .fake) throws -> HaloProject {
    HaloProject(services: services, document: try #require(HaloFixtures.project("keyed")))
}

/// `keyed` with a PNG sequence at half size started.
private func running() throws -> HaloProject {
    var project = try keyed()
    project.openRenderSheet()
    _ = project.startRender(pngHalf)
    return project
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

@Test func openRenderSheetSetsSettingsAndNoPlan() throws {
    var project = try keyed()
    project.openRenderSheet()
    let job = try #require(project.renderJob)
    #expect(job.plan == nil && job.outcome == nil && job.progress == 0)
    #expect(project.renderProgressText == nil && project.renderOutcomeText == nil)
    project.closeRenderSheet()
    #expect(project.renderJob == nil)
}

@Test func noCompositionOpensNothingAndStartsNothing() {
    var project = HaloProject(services: .fake)
    project.openRenderSheet()
    #expect(project.renderJob == nil)
    #expect(project.startRender(pngHalf) == nil)
    #expect(project.renderOutputName(pngHalf, existing: []) == nil)
    #expect(project.renderSummary(pngHalf, existing: []) == nil)
}

@Test func progressShowsAtOnce() throws {
    var project = try keyed()
    project.openRenderSheet()
    let result = project.startRender(pngHalf)
    let started = try #require(result)
    #expect(started.plan.frames == Array(0..<48))
    #expect(started.plan.width == 960 && started.plan.height == 540)
    #expect(started.composition.name == "Bounce")
    #expect(project.renderJob?.settings == pngHalf)
    #expect(project.renderProgressText == "Frame 0 of 48")
}

@Test func progressNeverGoesBackOrPastTheEnd() throws {
    var project = try running()
    project.renderProgress(frame: 12)
    #expect(project.renderProgressText == "Frame 12 of 48")
    project.renderProgress(frame: 11)
    #expect(project.renderProgressText == "Frame 12 of 48")
    project.renderProgress(frame: 99)
    #expect(project.renderProgressText == "Frame 48 of 48")
}

@Test func finishedRenderSaysHowMany() throws {
    var project = try running()
    project.renderProgress(frame: 48)
    project.finishRender(.finished(frames: 48))
    #expect(project.renderOutcomeText == "Rendered 48 frames.")
    #expect(project.renderProgressText == nil)
    project.renderProgress(frame: 3)
    project.finishRender(.cancelled(frames: 3))
    #expect(project.renderOutcomeText == "Rendered 48 frames.")
    project.closeRenderSheet()
    #expect(project.renderJob == nil)
}

@Test func cancelStopsAtTheFramesWrittenAndTakesTheExactCount() throws {
    var project = try running()
    project.renderProgress(frame: 12)
    project.cancelRender()
    #expect(project.renderOutcomeText == "Cancelled after 12 frames.")
    #expect(project.renderProgressText == nil)
    project.renderProgress(frame: 13)
    #expect(project.renderJob?.progress == 12)
    #expect(project.renderOutcomeText == "Cancelled after 12 frames.")
    project.finishRender(.finished(frames: 48))
    #expect(project.renderOutcomeText == "Cancelled after 12 frames.")
    project.finishRender(.cancelled(frames: 13))
    #expect(project.renderOutcomeText == "Cancelled after 13 frames.")
}

@Test func aFailureAfterCancelReplacesIt() throws {
    var project = try running()
    project.cancelRender()
    project.finishRender(.failed(frame: 2, message: "Disk full"))
    #expect(project.renderOutcomeText == "Render stopped at frame 2: Disk full.")
}

@Test func cancelledMovieSaysNoMovieWasWritten() throws {
    var project = try keyed()
    project.openRenderSheet()
    _ = project.startRender(movieFull)
    project.renderProgress(frame: 7)
    project.cancelRender()
    #expect(project.renderOutcomeText == "Cancelled. No movie was written.")
}

@Test func failureNamesTheFrame() throws {
    var project = try running()
    project.renderProgress(frame: 5)
    project.finishRender(.failed(frame: 5, message: "Disk full"))
    #expect(project.renderOutcomeText == "Render stopped at frame 5: Disk full.")
    project.finishRender(.finished(frames: 48))
    #expect(project.renderOutcomeText == "Render stopped at frame 5: Disk full.")
}

@Test func aSecondRenderCantStartWhileOneRuns() throws {
    var project = try running()
    project.renderProgress(frame: 4)
    #expect(project.startRender(movieFull) == nil)
    #expect(project.renderJob?.settings == pngHalf)
    project.openRenderSheet()
    #expect(project.renderProgressText == "Frame 4 of 48")
    project.finishRender(.finished(frames: 48))
    #expect(project.startRender(movieFull) != nil)
    #expect(project.renderProgressText == "Frame 0 of 48")
}

@Test func closeIsRefusedWhileRunning() throws {
    var project = try running()
    project.renderProgress(frame: 4)
    let before = project.renderJob
    project.closeRenderSheet()
    #expect(project.renderJob == before)
    #expect(project.renderJob != nil)
}

@Test func cancelBeforeStartingClosesTheSheet() throws {
    var project = try keyed()
    project.openRenderSheet()
    project.cancelRender()
    #expect(project.renderJob == nil)
}

@Test func aRefusedPlanShowsItsMessageAndStartsNothing() throws {
    var services = HaloServices.fake
    services.compositionRendering = RefusingRendering()
    var project = try keyed(services)
    project.openRenderSheet()
    #expect(project.startRender(pngHalf) == nil)
    #expect(project.renderJob?.plan == nil)
    #expect(project.renderProgressText == nil)
    #expect(project.renderOutcomeText == "Rendering isn't built yet.")
    #expect(project.renderSummary(pngHalf, existing: []) == nil)
    project.closeRenderSheet()
    #expect(project.renderJob == nil)
}

@Test func outputNamesNeverCollide() throws {
    let project = try keyed()
    #expect(project.renderOutputName(pngHalf, existing: []) == "Bounce")
    #expect(project.renderOutputName(pngHalf, existing: ["Bounce"]) == "Bounce 2")
    #expect(project.renderOutputName(pngHalf, existing: ["bounce", "Bounce 2"]) == "Bounce 3")
    #expect(project.renderOutputName(movieFull, existing: ["Bounce"]) == "Bounce.mp4")
    #expect(project.renderOutputName(movieFull, existing: ["Bounce.mp4"]) == "Bounce 2.mp4")
}

@Test func summaryReadsWhatTheRenderWrites() throws {
    let project = try keyed()
    #expect(project.renderSummary(pngHalf, existing: []) == "48 PNG files, 960 × 540, into a new folder \"Bounce\"")
    #expect(project.renderSummary(pngHalf, existing: ["Bounce"])
        == "48 PNG files, 960 × 540, into a new folder \"Bounce 2\"")
    #expect(project.renderSummary(movieFull, existing: []) == "One movie, 1920 × 1080, 24 fps, \"Bounce.mp4\"")
}
