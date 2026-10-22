// HaloDragPacerTests.swift: viewer-drag moves coalesced to at most one write
// per display refresh (#4276). The latest point wins, a held point flushes
// once its refresh is due, mouse-up hands back the exact final point, and a
// paced drag is still one "Move" undo step at that final point. Linux and macOS.
@testable import HaloModel
import Testing

private let tick = 1.0 / 60

private func keyedProject() throws -> HaloProject {
    let state = try #require(HaloFixtures.project("keyed"))
    var project = HaloProject(services: .fake)
    project.restore(state)
    project.scrub(to: 12)
    return project
}

@Test func dragPacerWritesTheFirstMoveAtOnce() {
    var pacer = HaloDragPacer(interval: tick)
    #expect(pacer.move(to: HaloPoint(x: 1, y: 1), now: 10) == HaloPoint(x: 1, y: 1))
    #expect(pacer.pending == nil)
    #expect(pacer.due == nil)
}

@Test func dragPacerHoldsMovesInsideOneRefreshAndTheLatestWins() {
    var pacer = HaloDragPacer(interval: tick)
    _ = pacer.move(to: HaloPoint(x: 1, y: 1), now: 10)
    #expect(pacer.move(to: HaloPoint(x: 2, y: 2), now: 10.004) == nil)
    #expect(pacer.move(to: HaloPoint(x: 3, y: 5), now: 10.008) == nil)
    #expect(pacer.pending == HaloPoint(x: 3, y: 5))
    #expect(pacer.due == 10 + tick)
    // Too early: still held.
    #expect(pacer.flush(now: 10.01) == nil)
    // Due: the latest point, once.
    #expect(pacer.flush(now: 10.02) == HaloPoint(x: 3, y: 5))
    #expect(pacer.flush(now: 10.04) == nil)
    #expect(pacer.due == nil)
}

@Test func dragPacerWritesAgainOnceARefreshHasPassed() {
    var pacer = HaloDragPacer(interval: tick)
    _ = pacer.move(to: HaloPoint(x: 1, y: 1), now: 10)
    #expect(pacer.move(to: HaloPoint(x: 4, y: 4), now: 10.02) == HaloPoint(x: 4, y: 4))
    #expect(pacer.pending == nil)
}

@Test func dragPacerCapsWritesAtOnePerRefresh() {
    // 120 samples at 120 Hz over one second: about 60 writes, never 120.
    var pacer = HaloDragPacer(interval: tick)
    var writes = 0
    for i in 0..<120 {
        let now = 10 + Double(i) / 120
        if pacer.flush(now: now) != nil { writes += 1 }
        if pacer.move(to: HaloPoint(x: Double(i), y: 0), now: now) != nil { writes += 1 }
    }
    #expect(writes <= 61)
    #expect(writes >= 40)
}

@Test func dragPacerEndHandsBackTheExactFinalPoint() {
    var pacer = HaloDragPacer(interval: tick)
    _ = pacer.move(to: HaloPoint(x: 1, y: 1), now: 10)
    _ = pacer.move(to: HaloPoint(x: 7.25, y: -3.5), now: 10.001)
    #expect(pacer.end() == HaloPoint(x: 7.25, y: -3.5))
    #expect(pacer == HaloDragPacer(interval: tick))
    #expect(pacer.end() == nil)
}

@Test func dragPacerCancelDropsTheHeldPoint() {
    var pacer = HaloDragPacer(interval: tick)
    _ = pacer.move(to: HaloPoint(x: 1, y: 1), now: 10)
    _ = pacer.move(to: HaloPoint(x: 2, y: 2), now: 10.001)
    pacer.cancel()
    #expect(pacer.pending == nil)
    #expect(pacer.end() == nil)
}

@Test func dragPacerFallsBackToSixtyHertzForABadInterval() {
    #expect(HaloDragPacer(interval: 0).interval == tick)
    #expect(HaloDragPacer(interval: -1).interval == tick)
    #expect(HaloDragPacer(interval: .nan).interval == tick)
    #expect(HaloDragPacer(interval: 1.0 / 120).interval == 1.0 / 120)
}

@Test func pacedViewerDragIsOneMoveStepAtTheFinalPoint() throws {
    var paced = try keyedProject()
    var direct = paced
    let comp = try #require(paced.selectedComposition)
    let ball = try #require(comp.layers.first { $0.name == "Ball" })
    let world = try #require(HaloKeyRules.worldMatrix(of: ball.id, in: comp, at: comp.playheadFrame))
    let b = ball.bounds(in: comp)
    let start = world.apply(HaloPoint(x: b.x + b.width / 2, y: b.y + b.height / 2))
    let end = HaloPoint(x: start.x + 37.5, y: start.y - 12.25)

    let steps = paced.history.undo.count
    var pacer = HaloDragPacer(interval: tick)
    paced.beginViewerDrag(at: start)
    for i in 1...40 {
        let f = Double(i) / 40
        let p = HaloPoint(x: start.x + (end.x - start.x) * f, y: start.y + (end.y - start.y) * f)
        let now = 10 + Double(i) / 120
        if let due = pacer.flush(now: now) { paced.moveViewerDrag(to: due) }
        if let write = pacer.move(to: p, now: now) { paced.moveViewerDrag(to: write) }
    }
    if let last = pacer.end() { paced.moveViewerDrag(to: last) }
    paced.endViewerDrag()

    direct.beginViewerDrag(at: start)
    direct.moveViewerDrag(to: end)
    direct.endViewerDrag()

    #expect(paced.history.undo.count == steps + 1)
    #expect(paced.history.undoTitle == "Undo Move")
    #expect(paced.selectedComposition == direct.selectedComposition)
}
