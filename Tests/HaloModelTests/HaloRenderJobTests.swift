// HaloRenderJobTests.swift: the pure helpers behind File > Render… (RO-3,
// #429; trimmed to them in core-loop CL-6, #1971) on the `keyed` fixture
// ("Bounce", 1920 × 1080, 24 fps, 48 frames) with the fake services: the
// output name, the summary and what a finished run wrote. The job's
// transitions are HaloRenderRunTests'.
// Runs on Linux and macOS.
import HaloModel
import Testing

private let pngHalf = HaloRenderSettings(format: .pngSequence, halfSize: true)
private let movieFull = HaloRenderSettings(format: .movie)

private func keyed(_ services: HaloServices = .fake) throws -> HaloProject {
    HaloProject(services: services, document: try #require(HaloFixtures.project("keyed")))
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

@Test func noCompositionNamesNothing() {
    let project = HaloProject(services: .fake)
    #expect(project.renderOutputName(pngHalf, existing: []) == nil)
    #expect(project.renderSummary(pngHalf, existing: []) == nil)
}

@Test func aRefusedPlanHasNoSummary() throws {
    var services = HaloServices.fake
    services.compositionRendering = RefusingRendering()
    #expect(try keyed(services).renderSummary(pngHalf, existing: []) == nil)
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

/// `keyed` with `settings` begun, started and finished at 48 frames.
private func finished(_ settings: HaloRenderSettings) throws -> HaloProject {
    var project = try keyed()
    let begun = project.beginRender(settings), started = project.startRender()
    #expect(begun && started != nil)
    project.endRender(.finished(frames: 48))
    return project
}

@Test func writtenTextGivesTheCountAndKind() throws {
    #expect(try finished(pngHalf).renderWrittenText(into: "Bounce") == "48 PNG files into \"Bounce\"")
    #expect(try finished(movieFull).renderWrittenText(into: "Bounce 2.mp4") == "Bounce 2.mp4")
}

@Test func writtenTextOnlyOnceFinished() throws {
    var project = try keyed()
    #expect(project.renderWrittenText(into: "Bounce") == nil)
    _ = project.beginRender(pngHalf)
    #expect(project.renderWrittenText(into: "Bounce") == nil)
}
