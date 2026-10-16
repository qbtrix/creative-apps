// HaloPlaybackWritesTests.swift: what playback and scrubbing write (#1296).
// The window ticks and scrubs only when `tickChanges(now:)` and
// `scrubChanges(to:)` say the call would change something, so a refresh or a
// drag sample between two frames writes nothing and SwiftUI runs no body for
// it. 120 ticks at 120 Hz on `keyed` (24 fps) write 24 times and land where
// unguarded ticks land; a scrub while playing still re-anchors, though the
// shown frame stays put; a play-once end and a non-finite `now` are judged
// right; a ruler drag writes once per frame it reaches. Linux and macOS.
@testable import HaloModel
import Testing

private func keyed(_ services: HaloServices, loops: Bool = true) throws -> HaloProject {
    var project = HaloProject(services: services)
    project.restore(try #require(HaloFixtures.project("keyed")))
    project.setLoops(loops)
    return project
}

/// The window's tick route: ticks only when the tick changes something.
private func routedTick(_ project: inout HaloProject, now: Double) -> Bool {
    guard project.tickChanges(now: now) else { return false }
    project.tick(now: now)
    return true
}

@Test(arguments: [HaloServices.fake, .live])
func aSecondAt120HzWritesOncePerFrame(services: HaloServices) throws {
    var routed = try keyed(services)
    #expect(routed.selectedComposition?.framesPerSecond == 24)
    routed.play(at: 100)
    var direct = routed
    var writes = 0
    for i in 1...120 {
        let now = 100 + Double(i) / 120
        if routedTick(&routed, now: now) { writes += 1 }
        direct.tick(now: now)
        #expect(routed == direct, "tick \(i) at \(now) drifted from an unguarded tick")
    }
    #expect(writes == 24, "120 refreshes of a 24 fps comp wrote \(writes) times")
    #expect(routed.selectedComposition?.playheadFrame == 24)
}

@Test(arguments: [HaloServices.fake, .live])
func aScrubWhilePlayingStillReanchors(services: HaloServices) throws {
    var project = try keyed(services)
    project.play(at: 100)
    for i in 1...50 { _ = routedTick(&project, now: 100 + Double(i) / 120) }
    #expect(project.selectedComposition?.playheadFrame == 10)
    project.scrub(to: 30)
    // The first tick after the scrub shows 30 again but moves the anchor.
    #expect(project.tickChanges(now: 101))
    #expect(routedTick(&project, now: 101))
    #expect(project.playback.startFrame == 30)
    #expect(project.playback.startTime == 101)
    for i in 1...5 { _ = routedTick(&project, now: 101 + Double(i) / 120) }
    #expect(project.selectedComposition?.playheadFrame == 31)
    #expect(project.playback.playing)
}

@Test(arguments: [HaloServices.fake, .live])
func endsAndHeldFramesAreJudgedRight(services: HaloServices) throws {
    var project = try keyed(services, loops: false)
    project.play(at: 100)
    // A non-finite now holds the frame: nothing to write.
    #expect(!project.tickChanges(now: .nan))
    #expect(!project.tickChanges(now: 100))
    // Past the end of a play-once pass the tick stops playback: a write.
    #expect(project.tickChanges(now: 103))
    project.tick(now: 103)
    #expect(!project.playback.playing)
    #expect(!project.tickChanges(now: 104))
    // Paused: a tick changes nothing.
    project.play(at: 200)
    project.pause()
    #expect(!project.tickChanges(now: 201))
}

@Test(arguments: [HaloServices.fake, .live])
func aRulerDragWritesOncePerFrameItReaches(services: HaloServices) throws {
    var project = try keyed(services)
    // 120 samples over frames 0...12, then past both ends.
    let samples = (0..<120).map { $0 / 10 } + [-5, -1, 60, 99]
    var writes = 0
    var direct = project
    for frame in samples {
        if project.scrubChanges(to: frame) {
            project.scrub(to: frame)
            writes += 1
        }
        direct.scrub(to: frame)
        #expect(project == direct)
    }
    // 1...11 (0 is already shown), back to 0 at -5, and 47 at 60.
    #expect(writes == 13, "the drag wrote \(writes) times")
    #expect(project.selectedComposition?.playheadFrame == 47)
    #expect(!project.scrubChanges(to: 47))
    #expect(!project.scrubChanges(to: 48))
    #expect(project.scrubChanges(to: 46))
    #expect(!HaloProject(services: services).scrubChanges(to: 3))
}
