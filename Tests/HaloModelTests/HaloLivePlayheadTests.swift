// HaloLivePlayheadTests.swift: ticks and ruler scrubs shown live, off the
// window's project (#4274, #4448). A ruler drag leaves the window's project
// untouched until it is taken back, then holds the last frame, exactly as
// writing every scrub would; a playing tick does the same; a step of the
// other kind takes the pending one back first; play-once's end writes at
// once. Linux and macOS.
@testable import HaloModel
import Testing

private func keyed(_ services: HaloServices, loops: Bool = true) throws -> HaloProject {
    var project = HaloProject(services: services)
    project.restore(try #require(HaloFixtures.project("keyed")))
    project.setLoops(loops)
    return project
}

/// The window's route: writes what the outcome writes, shows what it shows.
private func route(
    _ step: HaloLivePlayhead.Step, _ live: inout HaloLivePlayhead, model: inout HaloProject, shown: inout HaloProject?
) -> Bool {
    guard let outcome = live.apply(step, model: model, shown: shown) else { return false }
    shown = outcome.shown
    guard let write = outcome.write else { return false }
    model.landLive(write)
    return true
}

@Test(arguments: [HaloServices.fake, .live])
func aRulerDragWritesTheWindowOnceWhenTaken(services: HaloServices) throws {
    let start = try keyed(services)
    var model = start, direct = start, live = HaloLivePlayhead(), shown: HaloProject?
    let frames = [3, 4, 4, 9, 15, 15, 22, 18]
    for frame in frames {
        #expect(!route(.scrub(frame: frame), &live, model: &model, shown: &shown), "a scrub to \(frame) wrote the window")
        direct.scrub(to: frame)
        #expect(model == start, "a scrub to \(frame) changed the window's project")
        #expect(shown?.selectedComposition?.playheadFrame == frame)
    }
    #expect(live.pending == .scrub(frame: 18))
    let took = live.take(model)
    let taken = try #require(took)
    #expect(taken == direct, "taking the drag back drifted from writing every scrub")
    #expect(taken.selectedComposition?.playheadFrame == 18)
    #expect(live.pending == nil)
    #expect(live.take(taken) == nil, "a second take wrote again")
}

@Test(arguments: [HaloServices.fake, .live])
func aScrubOnTheShownFrameChangesNothing(services: HaloServices) throws {
    let start = try keyed(services)
    var live = HaloLivePlayhead()
    let applied = live.apply(.scrub(frame: 7), model: start, shown: nil)
    let first = try #require(applied)
    #expect(live.apply(.scrub(frame: 7), model: start, shown: first.shown) == nil)
    // Back to the window's own frame: shown live, and taking it writes nothing.
    let home = start.selectedComposition?.playheadFrame ?? 0
    let returned = live.apply(.scrub(frame: home), model: start, shown: first.shown)
    let back = try #require(returned)
    #expect(back.write == nil)
    #expect(back.shown?.selectedComposition?.playheadFrame == home)
    #expect(live.take(start) == nil)
}

@Test(arguments: [HaloServices.fake, .live])
func playingTicksWriteOnlyWhenTakenOrAtTheEnd(services: HaloServices) throws {
    var model = try keyed(services, loops: false)
    model.play(at: 100)
    let playing = model
    var direct = model, live = HaloLivePlayhead(), shown: HaloProject?
    for i in 1...24 {
        let now = 100 + Double(i) / 120
        #expect(!route(.tick(now: now), &live, model: &model, shown: &shown), "tick \(i) wrote the window")
        direct.tick(now: now)
        #expect((shown ?? model).selectedComposition?.playheadFrame == direct.selectedComposition?.playheadFrame)
    }
    #expect(model == playing)
    // Play-once's end writes at once and shows nothing live.
    #expect(route(.tick(now: 200), &live, model: &model, shown: &shown))
    #expect(!model.playback.playing)
    #expect(shown == nil)
    #expect(live.pending == nil)
}

@Test(arguments: [HaloServices.fake, .live])
func aStepOfTheOtherKindTakesThePendingOneFirst(services: HaloServices) throws {
    var model = try keyed(services)
    model.play(at: 100)
    var live = HaloLivePlayhead(), shown: HaloProject?
    for i in 1...50 { _ = route(.tick(now: 100 + Double(i) / 120), &live, model: &model, shown: &shown) }
    #expect(model.selectedComposition?.playheadFrame == 0)
    // A scrub while playing writes the playing frame back, then shows the scrub.
    #expect(route(.scrub(frame: 30), &live, model: &model, shown: &shown))
    #expect(model.selectedComposition?.playheadFrame == 10)
    #expect(shown?.selectedComposition?.playheadFrame == 30)
    #expect(live.pending == .scrub(frame: 30))
    // The next tick writes the scrub back, so playback re-anchors on it.
    #expect(route(.tick(now: 101), &live, model: &model, shown: &shown))
    #expect(model.selectedComposition?.playheadFrame == 30)
    #expect(shown?.playback.startFrame == 30)
    #expect(shown?.playback.startTime == 101)
    #expect(live.pending == .tick(now: 101))
}
