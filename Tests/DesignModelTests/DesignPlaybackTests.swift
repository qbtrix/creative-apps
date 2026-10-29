// DesignPlaybackTests.swift: Design plays on the suite's one clock (one-document OD-11). DesignTransport turns the
// seconds played into a frame through SuiteKernel's PlaybackTiming at the document's rate and length (60 fps,
// 300 frames by default), from the total time played, so a stutter of the link skips frames instead of slowing
// play. Play once ends on the last frame; stop goes back to the rest pose. Showing a transport frame moves the
// playhead only: no undo step, no unsaved change. Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignPlaybackTests {
    let time = DesignDocumentTime()

    @Test func ticksAdvanceByTheTimePlayedFromTheStartFrame() {
        var t = DesignTransport()
        t.play(from: 10, time: time)
        #expect(t.isPlaying && t.frame == 10)
        #expect(t.tick(by: 0.5, time: time) == 40)
        #expect(t.tick(by: 0.25, time: time) == 55)
        #expect(t.tick(by: .nan, time: time) == 55, "a bad step holds the frame")
    }

    @Test func playOnceEndsOnTheLastFrameAndLoopWraps() {
        var t = DesignTransport()
        t.play(from: 0, time: time)
        t.tick(by: 10, time: time)
        #expect(!t.isPlaying && t.frame == 299)
        t.play(from: t.frame, time: time)
        #expect(t.frame == 0, "play at the end starts over")
        var loop = DesignTransport()
        loop.loops = true
        loop.play(from: 290, time: time)
        #expect(loop.tick(by: 0.25, time: time) == 5 && loop.isPlaying)
    }

    @Test func pauseKeepsTheFrameAndStopGoesBackToTheRestPose() {
        var t = DesignTransport()
        t.play(from: nil, time: time)
        t.tick(by: 1, time: time)
        t.pause()
        #expect(!t.isPlaying && t.frame == 60)
        #expect(t.tick(by: 1, time: time) == 60, "a paused transport doesn't move")
        t.stop()
        #expect(t.frame == nil && !t.isPlaying)
    }

    @Test func showingAFrameIsNeverAnEditOrAnUnsavedChange() throws {
        var w = DesignFixtures.animated(50)
        let (dirty, undo, page) = (w.isDirty, w.canUndo, w.selectedPage)
        var t = DesignTransport()
        t.play(from: nil, time: w.time)
        for _ in 0..<120 { t.tick(by: 1.0 / 120, time: w.time); w.show(t) }
        #expect(w.playhead == 60)
        #expect(w.isDirty == dirty && w.canUndo == undo && w.selectedPage == page)
        t.stop()
        w.show(t)
        #expect(w.playhead == nil && w.shownPage == page)
    }
}
