// HaloTransportStateTests.swift: the transport's enabled set follows the
// frame shown (#4352). A ruler scrub that ends on the last frame disables
// Next and End and enables Start and Previous on the live frame, before the
// window takes it back, and the same once taken; at the start it is the
// reverse. Each button's help and enabled state agree. Linux and macOS.
@testable import HaloModel
import Testing

private func reference(_ services: HaloServices) throws -> HaloProject {
    var project = HaloProject(services: services)
    project.restore(try #require(HaloFixtures.project("reference")))
    return project
}

@Test(arguments: [HaloServices.fake, .live])
func aScrubEndingOnTheLastFrameDisablesNextAndEnd(services: HaloServices) throws {
    var model = try reference(services)
    let last = try #require(model.selectedComposition?.lastFrame)
    #expect(last > 1)
    var live = HaloLivePlayhead()
    var shown: HaloProject?
    for frame in [0, last / 2, last - 1, last] {
        guard let outcome = live.apply(.scrub(frame: frame), model: model, shown: shown) else { continue }
        shown = outcome.shown
        if let write = outcome.write { model.landLive(write) }
    }
    let onScreen = HaloTransportState(try #require(shown))
    #expect(!onScreen.enabled.contains(.nextFrame))
    #expect(!onScreen.enabled.contains(.goToEnd))
    #expect(onScreen.enabled.isSuperset(of: [.goToStart, .previousFrame]))
    let took = live.take(model)
    let taken = try #require(took)
    #expect(HaloTransportState(taken).enabled == onScreen.enabled)
}

@Test(arguments: [HaloServices.fake, .live])
func atTheStartStartAndPreviousAreDisabled(services: HaloServices) throws {
    var project = try reference(services)
    project.scrub(to: 0)
    let state = HaloTransportState(project)
    #expect(!state.enabled.contains(.goToStart))
    #expect(!state.enabled.contains(.previousFrame))
    #expect(state.enabled.isSuperset(of: [.nextFrame, .goToEnd]))
}

@Test func eachButtonsHelpMatchesItsEnabledState() throws {
    var project = try reference(.fake)
    project.goToEnd()
    let state = HaloTransportState(project)
    #expect(state.buttons.map(\.command) == HaloTransportState.commands)
    for button in state.buttons {
        #expect(button.unavailableHelp == project.unavailableHelp(for: button.command))
        #expect(button.isEnabled == (button.unavailableHelp == nil))
        if let why = button.unavailableHelp { #expect(button.menuHelp == "\(button.title): \(why)") }
    }
}
