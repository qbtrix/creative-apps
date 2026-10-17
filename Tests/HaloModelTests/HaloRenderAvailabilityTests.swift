// HaloRenderAvailabilityTests.swift: RO-4, QB-F1 for rendering. Render Frame
// and Render… are off with no composition, on for `keyed` on `.fake` and
// `.live`; while a render runs Render… (and Render) say so and Render Frame
// stays on; with nothing in the way each command takes its service's own
// help. Cancel and Close answer from the job. Linux and macOS.
@testable import HaloModel
import Testing

private let pngHalf = HaloRenderSettings(format: .pngSequence, halfSize: true)
private let allRender: [HaloCommand] = [
    .renderFrame, .openRenderSheet, .startRender(pngHalf), .cancelRender, .closeRenderSheet,
]

private func keyed(_ services: HaloServices = .fake) throws -> HaloProject {
    HaloProject(services: services, document: try #require(HaloFixtures.project("keyed")))
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

@Test(arguments: [HaloServices.fake, .live])
func noCompositionTurnsEveryRenderCommandOff(services: HaloServices) {
    let none = HaloProject(services: services)
    for command in allRender {
        #expect(none.unavailableHelp(for: command) == "Create a composition first.", "\(command)")
    }
}

@Test(arguments: [HaloServices.fake, .live])
func renderFrameAndRenderSheetAreOnForAComposition(services: HaloServices) throws {
    let project = try keyed(services)
    #expect(project.unavailableHelp(for: .renderFrame) == nil)
    #expect(project.unavailableHelp(for: .openRenderSheet) == nil)
    #expect(project.unavailableHelp(for: .startRender(pngHalf)) == nil)
}

@Test func aRunningRenderBlocksASecondButNotRenderFrame() throws {
    var project = try keyed()
    project.openRenderSheet()
    #expect(project.startRender(pngHalf) != nil)
    #expect(project.unavailableHelp(for: .openRenderSheet) == "A render is already running.")
    #expect(project.unavailableHelp(for: .startRender(pngHalf)) == "A render is already running.")
    #expect(project.startRender(pngHalf) == nil)
    #expect(project.unavailableHelp(for: .renderFrame) == nil)
    #expect(project.unavailableHelp(for: .cancelRender) == nil)
    #expect(project.unavailableHelp(for: .closeRenderSheet) == "Cancel the render first.")
    project.renderCurrentFrame()
    #expect(project.renderedFrame != nil)
}

@Test func anEndedRenderLetsTheNextOneStart() throws {
    var project = try keyed()
    project.openRenderSheet()
    _ = project.startRender(pngHalf)
    project.finishRender(.finished(frames: 48))
    #expect(project.unavailableHelp(for: .openRenderSheet) == nil)
    #expect(project.unavailableHelp(for: .startRender(pngHalf)) == nil)
    #expect(project.unavailableHelp(for: .cancelRender) == "The render has already ended.")
    #expect(project.unavailableHelp(for: .closeRenderSheet) == nil)
}

@Test func cancelAndCloseNeedAnOpenSheet() throws {
    var project = try keyed()
    #expect(project.unavailableHelp(for: .cancelRender) == "No render is open.")
    #expect(project.unavailableHelp(for: .closeRenderSheet) == "No render is open.")
    project.openRenderSheet()
    #expect(project.unavailableHelp(for: .cancelRender) == nil)
    #expect(project.unavailableHelp(for: .closeRenderSheet) == nil)
}

@Test func aRefusedPlanStillLetsCancelCloseTheSheet() throws {
    var services = HaloServices.fake
    services.compositionRendering = HelpCompositionRendering(help: "x")
    var project = try keyed(services)
    project.openRenderSheet()
    #expect(project.startRender(pngHalf) == nil)
    #expect(project.renderJob?.outcome != nil)
    #expect(project.unavailableHelp(for: .cancelRender) == nil)
    project.cancelRender()
    #expect(project.renderJob == nil)
}

@Test func eachCommandTakesItsServicesHelp() throws {
    var services = HaloServices.fake
    services.compositionRendering = HelpCompositionRendering(help: "x")
    #expect(try keyed(services).unavailableHelp(for: .openRenderSheet) == "x")
    #expect(try keyed(services).unavailableHelp(for: .startRender(pngHalf)) == "x")
    #expect(try keyed(services).unavailableHelp(for: .renderFrame) == nil)
    services.rendering = HelpFrameRendering(help: "y")
    #expect(try keyed(services).unavailableHelp(for: .renderFrame) == "y")
}
