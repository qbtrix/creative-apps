// HaloRenderAvailabilityTests.swift: core-loop CL-7 (RO-4, QB-F1 for
// rendering). Availability reads the kernel's `renderRun`: Render Frame and
// Render… are off with no composition and on for `keyed` on `.fake` and
// `.live`; while a render runs Render… says so and Render Frame stays on; a
// finished render lets the next one open; the sheet's own commands are on
// only in the state they act in (Render while editing, Cancel while running,
// Close while editing, finished or failed); the catalog's Render… and Close
// Render move the kernel's run (CL-6). Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

private let pngHalf = HaloRenderSettings(format: .pngSequence, halfSize: true)
private let sheetCommands: [HaloCommand] = [.startRender(pngHalf), .cancelRender, .closeRenderSheet]

private func keyed(_ services: HaloServices = .fake) throws -> HaloProject {
    HaloProject(services: services, document: try #require(HaloFixtures.project("keyed")))
}

/// `keyed` with its render run in `state`, reached through the Model's methods.
private func keyed(in state: String) throws -> HaloProject {
    var project = try keyed()
    guard state != "idle" else { return project }
    project.beginRender(pngHalf)
    guard state != "editing" else { return project }
    _ = project.startRender()
    switch state {
    case "finished": project.endRender(.finished(frames: 48))
    case "failed": project.endRender(.failed(frame: 5, message: "Disk full."))
    default: break
    }
    return project
}

/// The sheet commands that are on, by name.
private func enabled(_ project: HaloProject) -> [String] {
    sheetCommands.filter { project.unavailableHelp(for: $0) == nil }.map { "\($0)".components(separatedBy: "(")[0] }
}

/// A composition renderer that is not built, so its commands say `help`.
private struct HelpCompositionRendering: CompositionRendering {
    let help: String
    var unavailableHelp: String? { help }
    func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        throw HaloEditError.notBuilt("Rendering")
    }
    func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, text: (any TextRasterizing)?,
        into sink: inout some RenderSink, isCancelled: () -> Bool
    ) -> HaloRenderOutcome { .failed(frame: 0, message: "unused") }
}

/// A frame renderer that is not built, so Render Frame says `help`.
private struct HelpFrameRendering: FrameRendering {
    let help: String
    var unavailableHelp: String? { help }
    func render(_ list: HaloDrawList, width: Int, height: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame {
        throw HaloEditError.notBuilt("Rendering")
    }
}

@Suite struct HaloRenderAvailabilityTests {
    @Test(arguments: [HaloServices.fake, .live])
    func noCompositionTurnsRenderFrameAndRenderOff(services: HaloServices) {
        let none = HaloProject(services: services)
        #expect(none.unavailableHelp(for: .renderFrame) == "Create a composition first.")
        #expect(none.unavailableHelp(for: .openRenderSheet) == "Create a composition first.")
        for command in sheetCommands {
            #expect(none.unavailableHelp(for: command) != nil, "\(command)")
        }
    }

    @Test(arguments: [HaloServices.fake, .live])
    func keyedTurnsRenderFrameAndRenderOn(services: HaloServices) throws {
        let project = try keyed(services)
        #expect(project.renderRun == .idle)
        #expect(project.unavailableHelp(for: .renderFrame) == nil)
        #expect(project.unavailableHelp(for: .openRenderSheet) == nil)
    }

    @Test func renderDisabledWhileRunning() throws {
        var project = try keyed(in: "running")
        guard case .running = project.renderRun else { Issue.record("not running"); return }
        #expect(project.unavailableHelp(for: .openRenderSheet) == "A render is already running.")
        #expect(project.unavailableHelp(for: .startRender(pngHalf)) == "A render is already running.")
        #expect(project.unavailableHelp(for: .renderFrame) == nil)
        project.renderCurrentFrame()
        #expect(project.renderedFrame != nil)
    }

    @Test func renderEnabledAfterFinish() throws {
        let finished = try keyed(in: "finished")
        guard case .finished = finished.renderRun else { Issue.record("not finished"); return }
        #expect(finished.unavailableHelp(for: .openRenderSheet) == nil)
        #expect(finished.unavailableHelp(for: .renderFrame) == nil)
        #expect(try keyed(in: "failed").unavailableHelp(for: .openRenderSheet) == nil)
    }

    @Test func sheetCommandsActOnlyInTheirState() throws {
        #expect(enabled(try keyed(in: "idle")) == [])
        #expect(enabled(try keyed(in: "editing")) == ["startRender", "closeRenderSheet"])
        #expect(enabled(try keyed(in: "running")) == ["cancelRender"])
        #expect(enabled(try keyed(in: "finished")) == ["closeRenderSheet"])
        #expect(enabled(try keyed(in: "failed")) == ["closeRenderSheet"])
    }

    @Test func offSheetCommandsSayWhy() throws {
        let idle = try keyed(in: "idle"), running = try keyed(in: "running"), finished = try keyed(in: "finished")
        #expect(idle.unavailableHelp(for: .cancelRender) == "No render is open.")
        #expect(idle.unavailableHelp(for: .closeRenderSheet) == "No render is open.")
        #expect(try keyed(in: "editing").unavailableHelp(for: .cancelRender) == "No render is running.")
        #expect(running.unavailableHelp(for: .closeRenderSheet) == "Cancel the render first.")
        #expect(finished.unavailableHelp(for: .cancelRender) == "The render has already ended.")
        #expect(finished.unavailableHelp(for: .startRender(pngHalf)) == "The render has already ended.")
    }

    @Test func aRefusedPlanFailsAndCloseClosesTheSheet() throws {
        var services = HaloServices.fake
        services.compositionRendering = HelpCompositionRendering(help: "x")
        var project = try keyed(services)
        project.beginRender(pngHalf)
        #expect(project.startRender() == nil)
        guard case .failed = project.renderRun else { Issue.record("not failed"); return }
        #expect(project.unavailableHelp(for: .cancelRender) != nil)
        #expect(project.unavailableHelp(for: .closeRenderSheet) == nil)
        project.dismissRender()
        #expect(project.renderRun == .idle)
    }

    @Test func eachCommandTakesItsServicesHelp() throws {
        var services = HaloServices.fake
        services.compositionRendering = HelpCompositionRendering(help: "x")
        #expect(try keyed(services).unavailableHelp(for: .openRenderSheet) == "x")
        #expect(try keyed(services).unavailableHelp(for: .renderFrame) == nil)
        services.rendering = HelpFrameRendering(help: "y")
        #expect(try keyed(services).unavailableHelp(for: .renderFrame) == "y")
    }

    @Test func theCatalogsRenderSheetCommandsMoveTheKernelsRun() throws {
        var project = try keyed()
        _ = try HaloProject.catalog.run("render.open-sheet", params: .object([:]), on: &project)
        #expect(project.renderRun == .editing(HaloRenderSettings(format: .pngSequence)))
        _ = try HaloProject.catalog.run("render.close-sheet", params: .object([:]), on: &project)
        #expect(project.renderRun == .idle)
        project = try keyed(in: "finished")
        _ = try HaloProject.catalog.run("render.open-sheet", params: .object([:]), on: &project)
        #expect(project.renderOutcomeText == "Rendered 48 frames.")
        _ = try HaloProject.catalog.run("render.close-sheet", params: .object([:]), on: &project)
        #expect(project.renderRun == .idle && project.renderJob == nil)
    }
}
