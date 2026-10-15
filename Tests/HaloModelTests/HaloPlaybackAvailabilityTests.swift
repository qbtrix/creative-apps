// HaloPlaybackAvailabilityTests.swift: VP-7, QB-F1 for the transport. The
// six playback commands act or say why on `.fake` and `.live`: none without
// a composition, the steps and Go to Start / End off where they would do
// nothing, Play/Pause and Loop off with the clock's help; Set In / Out Point
// keep W0's answers. Linux and macOS.
@testable import HaloModel
import Testing

private let sixCommands: [HaloCommand] = [
    .playPause, .toggleLoop, .nextFrame, .previousFrame, .goToStart, .goToEnd,
]

/// A clock that is not built, so its controls say `help`.
private struct HelpClock: PlaybackClock {
    let help: String
    var unavailableHelp: String? { help }
    func tick(
        startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool
    ) -> HaloPlaybackTick {
        HaloPlaybackTick(frame: startFrame, ended: true)
    }
}

/// `three-layers` on `services` with the playhead on `frame`, no layer selected.
private func threeLayers(_ services: HaloServices, at frame: Int) throws -> HaloProject {
    var project = HaloProject(services: services)
    project.restore(try #require(HaloFixtures.project("three-layers")))
    project.scrub(to: frame)
    return project
}

@Test(arguments: [HaloServices.fake, .live])
func noCompositionTurnsThePlaybackCommandsOff(services: HaloServices) {
    let none = HaloProject(services: services)
    for command in sixCommands + [.setInPoint, .setOutPoint, .scrub(3), .tick(1)] {
        #expect(none.unavailableHelp(for: command) == "Create a composition first.", "\(command)")
    }
}

@Test(arguments: [HaloServices.fake, .live])
func onTheFirstFrameOnlyBackwardsIsOff(services: HaloServices) throws {
    let project = try threeLayers(services, at: 0)
    #expect(project.selectedComposition?.playheadFrame == 0)
    for command: HaloCommand in [.playPause, .toggleLoop, .nextFrame, .goToEnd, .scrub(12), .tick(1)] {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
    #expect(project.unavailableHelp(for: .previousFrame) == "Already on the first frame.")
    #expect(project.unavailableHelp(for: .goToStart) == "Already at the start.")
}

@Test(arguments: [HaloServices.fake, .live])
func onTheLastFrameOnlyForwardsIsOff(services: HaloServices) throws {
    let project = try threeLayers(services, at: 71)
    #expect(project.selectedComposition?.playheadFrame == 71)
    #expect(project.selectedComposition?.lastFrame == 71)
    for command: HaloCommand in [.playPause, .toggleLoop, .previousFrame, .goToStart] {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
    #expect(project.unavailableHelp(for: .nextFrame) == "Already on the last frame.")
    #expect(project.unavailableHelp(for: .goToEnd) == "Already at the end.")
}

@Test(arguments: [HaloServices.fake, .live])
func midwayEverythingIsOn(services: HaloServices) throws {
    let project = try threeLayers(services, at: 36)
    for command in sixCommands {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
}

@Test(arguments: [HaloServices.fake, .live])
func aClockWithHelpTurnsPlayAndLoopOff(services: HaloServices) throws {
    var withHelp = services
    withHelp.clock = HelpClock(help: "x")
    let project = try threeLayers(withHelp, at: 36)
    #expect(project.unavailableHelp(for: .playPause) == "x")
    #expect(project.unavailableHelp(for: .toggleLoop) == "x")
    for command: HaloCommand in [.nextFrame, .previousFrame, .goToStart, .goToEnd] {
        #expect(project.unavailableHelp(for: command) == nil, "\(command)")
    }
}

@Test(arguments: [HaloServices.fake, .live])
func inAndOutPointsKeepTheirAnswers(services: HaloServices) throws {
    var project = try threeLayers(services, at: 12)
    #expect(project.unavailableHelp(for: .setInPoint) == "Select a layer first.")
    #expect(project.unavailableHelp(for: .setOutPoint) == "Select a layer first.")
    let badge = try #require(project.selectedComposition?.layers.first { $0.name == "Badge" }).id
    project.selectLayer(badge)
    #expect(project.unavailableHelp(for: .setInPoint) == nil)
    #expect(project.unavailableHelp(for: .setOutPoint) == nil)
}
