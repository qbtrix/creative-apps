// HaloPlaybackTests.swift: VP-3's transport methods on `three-layers` (24 fps,
// 72 frames), on `.fake` and `.live`: play and tick land on the clock's
// frames, play anchors on the playhead, a scrub while playing and each loop
// wrap re-anchor, Loop off ends the pass, NaN holds the frame, steps clamp and
// pause, and none of it adds an undo step (QB-F3). Linux and macOS.
@testable import HaloModel
import Testing

private func threeLayers(_ services: HaloServices, at frame: Int = 0, loops: Bool = true) throws -> HaloProject {
    var project = HaloProject(services: services)
    project.restore(try #require(HaloFixtures.project("three-layers")))
    project.scrub(to: frame)
    project.setLoops(loops)
    return project
}

private func playhead(_ project: HaloProject) -> Int? { project.selectedComposition?.playheadFrame }

@Test(arguments: [HaloServices.fake, .live])
func playAdvancesAtTheFrameRate(services: HaloServices) throws {
    var project = try threeLayers(services)
    project.play(at: 100)
    #expect(project.playback.playing)
    let playing101 = project.tick(now: 101)
    #expect(playing101)
    #expect(playhead(project) == 24)
}

@Test(arguments: [HaloServices.fake, .live])
func playAnchorsOnThePlayheadWithoutReanchoring(services: HaloServices) throws {
    var project = try threeLayers(services, at: 60)
    project.play(at: 100)
    #expect(project.playback.lastFrame == 60)
    #expect(project.playback.startFrame == 60)
    project.tick(now: 100 + 1.0 / 24)
    #expect(playhead(project) == 61)
}

@Test(arguments: [HaloServices.fake, .live])
func loopingWrapsFromALateStart(services: HaloServices) throws {
    var project = try threeLayers(services, at: 60)
    project.play(at: 100)
    let playing102 = project.tick(now: 102)
    #expect(playing102)
    #expect(playhead(project) == 36)
}

@Test(arguments: [HaloServices.fake, .live])
func aScrubWhilePlayingContinuesFromTheScrub(services: HaloServices) throws {
    var project = try threeLayers(services)
    project.play(at: 100)
    project.tick(now: 100 + 10.0 / 24)
    #expect(playhead(project) == 10)
    project.scrub(to: 40)
    // The first tick after the scrub re-anchors on it (startTime = now), so
    // it shows 40 and the tick 1/24 s after it shows 41, not frame 11.
    project.tick(now: 101)
    #expect(playhead(project) == 40)
    #expect(project.playback.startFrame == 40)
    project.tick(now: 101 + 1.0 / 24)
    #expect(playhead(project) == 41)
    #expect(project.playback.playing)
}

@Test(arguments: [HaloServices.fake, .live])
func loopOffStopsOnTheLastFrame(services: HaloServices) throws {
    var project = try threeLayers(services, at: 60, loops: false)
    project.play(at: 100)
    let stopped101 = project.tick(now: 101)
    #expect(stopped101 == false)
    #expect(playhead(project) == 71)
    #expect(project.playback.playing == false)
    let stopped102 = project.tick(now: 102)
    #expect(stopped102 == false)
    #expect(playhead(project) == 71)
}

@Test(arguments: [HaloServices.fake, .live])
func playOnTheLastFrameWithLoopOffStartsAtZero(services: HaloServices) throws {
    var project = try threeLayers(services, at: 71, loops: false)
    project.play(at: 100)
    #expect(playhead(project) == 0)
    #expect(project.playback.startFrame == 0)
    #expect(project.playback.lastFrame == 0)
    project.tick(now: 100.5)
    #expect(playhead(project) == 12)
}

@Test(arguments: [HaloServices.fake, .live])
func loopOffMidPlayEndsThisPass(services: HaloServices) throws {
    var project = try threeLayers(services)
    project.play(at: 100)
    project.tick(now: 103.5)
    #expect(playhead(project) == 12)
    project.setLoops(false)
    let playing104 = project.tick(now: 104)
    #expect(playing104)
    #expect(playhead(project) == 24)
    #expect(project.playback.playing)
    let stopped110 = project.tick(now: 110)
    #expect(stopped110 == false)
    #expect(playhead(project) == 71)
}

@Test(arguments: [HaloServices.fake, .live])
func aNaNTickKeepsTheFrame(services: HaloServices) throws {
    var project = try threeLayers(services)
    project.play(at: 100)
    project.tick(now: 100.5)
    let playing_nan = project.tick(now: .nan)
    #expect(playing_nan)
    #expect(playhead(project) == 12)
    #expect(project.playback.playing)
    project.tick(now: 101)
    #expect(playhead(project) == 24)
}

@Test(arguments: [HaloServices.fake, .live])
func stepsClampAndPause(services: HaloServices) throws {
    var project = try threeLayers(services, at: 10)
    project.play(at: 100)
    project.stepFrame(by: 2)
    #expect(playhead(project) == 12)
    #expect(project.playback.playing == false)
    project.stepFrame(by: -20)
    #expect(playhead(project) == 0)
    project.scrub(to: 70)
    project.stepFrame(by: 5)
    #expect(playhead(project) == 71)
    project.stepFrame(by: .min)
    #expect(playhead(project) == 0)
    project.stepFrame(by: .max)
    #expect(playhead(project) == 71)
}

@Test(arguments: [HaloServices.fake, .live])
func startAndEndJumpAndPause(services: HaloServices) throws {
    var project = try threeLayers(services, at: 30)
    project.play(at: 100)
    project.goToEnd()
    #expect(playhead(project) == 71)
    #expect(project.playback.playing == false)
    project.play(at: 200)
    project.goToStart()
    #expect(playhead(project) == 0)
    #expect(project.playback.playing == false)
}

@Test(arguments: [HaloServices.fake, .live])
func noCompositionNeverPlays(services: HaloServices) {
    var project = HaloProject(services: services)
    project.play(at: 100)
    #expect(project.playback.playing == false)
    let stopped101 = project.tick(now: 101)
    #expect(stopped101 == false)
    project.stepFrame(by: 3)
    project.goToEnd()
    #expect(project.selectedComposition == nil)
}

@Test(arguments: [HaloServices.fake, .live])
func playbackIsNotAnUndoStep(services: HaloServices) throws {
    var project = try threeLayers(services)
    let before = project.history
    project.play(at: 100)
    for i in 1...100 { project.tick(now: 100 + Double(i) / 30) }
    project.stepFrame(by: 3)
    project.stepFrame(by: -1)
    project.togglePlay(at: 110)
    project.togglePlay(at: 111)
    project.setLoops(false)
    project.goToStart()
    project.goToEnd()
    #expect(project.history == before)
}

@Test(arguments: [HaloServices.fake, .live])
func labelsReadTheTransport(services: HaloServices) throws {
    var project = try threeLayers(services)
    #expect(project.playLabel == "Paused")
    #expect(project.loopLabel == "On")
    project.togglePlay(at: 100)
    #expect(project.playLabel == "Playing")
    project.togglePlay(at: 101)
    #expect(project.playLabel == "Paused")
    project.setLoops(false)
    #expect(project.loopLabel == "Off")
}
