// HaloInspectorScrubTests.swift: the inspector bar scrub's coalescer (#4275):
// one value written per refresh, every event shown by the refresh after it,
// a refresh asked for once, an idle refresh stops asking, and a late refresh
// writes at once.
import HaloModel
import Testing

@Suite struct HaloInspectorScrubTests {
    @Test func manySamplesInOneRefreshWriteOnlyTheLatestValue() {
        var scrub = HaloInspectorScrub()
        let steps = (0..<5).map { scrub.take(Double($0) * 10, at: 1 + Double($0) / 1000, now: 1 + Double($0) / 1000) }
        #expect(steps == [.askRefresh, .wait, .wait, .wait, .wait])
        let frame = scrub.refresh(at: 1.01)
        #expect(frame.value == 40)
        #expect(frame.events == [1, 1.001, 1.002, 1.003, 1.004])
        #expect(scrub.pending == nil && scrub.waiting.isEmpty && scrub.awaitsRefresh)
    }

    @Test func aMoveThatKeepsTheValueIsStillShown() {
        var scrub = HaloInspectorScrub()
        let step = scrub.take(nil, at: 2, now: 2)
        #expect(step == .askRefresh)
        let frame = scrub.refresh(at: 2.01)
        #expect(frame.value == nil && frame.events == [2] && !frame.isEmpty)
        #expect(scrub.awaitsRefresh)
    }

    @Test func oneEventSeenTwiceIsShownOnce() {
        var scrub = HaloInspectorScrub()
        _ = scrub.take(nil, at: 3, now: 3)
        _ = scrub.take(12, at: 3, now: 3)
        _ = scrub.take(.nan, at: .infinity, now: 3)
        let frame = scrub.refresh(at: 3.01)
        #expect(frame.events == [3])
        #expect(frame.value?.isNaN == true)
    }

    @Test func anIdleRefreshStopsAskingAndTheNextSampleAsksAgain() {
        var scrub = HaloInspectorScrub()
        _ = scrub.take(1, at: 1, now: 1)
        _ = scrub.refresh(at: 1.01)
        let again = scrub.take(2, at: 1.02, now: 1.02)
        #expect(again == .wait, "a refresh is still asked for")
        let busy = scrub.refresh(at: 1.03), idle = scrub.refresh(at: 1.04)
        #expect(busy.value == 2 && idle.isEmpty)
        #expect(!scrub.awaitsRefresh)
        let next = scrub.take(3, at: 2, now: 2)
        #expect(next == .askRefresh)
    }

    @Test func aLateRefreshWritesAtOnce() {
        var scrub = HaloInspectorScrub()
        let wait = HaloInspectorScrub.longestWait
        _ = scrub.take(1, at: 1, now: 1)
        let early = scrub.take(2, at: 1.01, now: 1 + wait * 0.9)
        let late = scrub.take(3, at: 1.02, now: 1 + wait * 1.1)
        #expect(early == .wait && late == .writeNow)
        let frame = scrub.refresh(at: 1 + wait * 1.1)
        #expect(frame.value == 3 && frame.events == [1, 1.01, 1.02])
        let after = scrub.take(4, at: 1.03, now: 1 + wait * 2)
        #expect(after == .wait, "the frame just taken resets the wait")
    }

    @Test func theEndHandsBackWhatNoRefreshTook() {
        var scrub = HaloInspectorScrub()
        _ = scrub.take(5, at: 1, now: 1)
        _ = scrub.refresh(at: 1.01)
        _ = scrub.take(7, at: 2, now: 2)
        let left = scrub.end()
        #expect(left == HaloScrubFrame(value: 7, events: [2]))
        #expect(scrub == HaloInspectorScrub())
        let none = scrub.end()
        #expect(none.isEmpty)
    }

    @Test func sixtyRefreshesOfDoubleRateInputWriteSixtyTimes() {
        var scrub = HaloInspectorScrub()
        var writes = 0, shown = 0, late = 0
        for refresh in 0..<60 {
            for half in 0..<2 {
                let t = Double(refresh * 2 + half) / 120
                if scrub.take(Double(refresh * 2 + half), at: t, now: t) == .writeNow { late += 1 }
            }
            let frame = scrub.refresh(at: Double(refresh * 2 + 2) / 120)
            if frame.value != nil { writes += 1 }
            shown += frame.events.count
        }
        #expect(writes == 60 && shown == 120 && late == 0)
    }
}
