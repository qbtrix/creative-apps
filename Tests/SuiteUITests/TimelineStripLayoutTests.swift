// TimelineStripLayoutTests.swift: the strip's layout arithmetic (timeline
// packet, TL-7). The ideal height is the ruler plus every lane, plus the
// toolbar row when it is on, so a host inside its own vertical ScrollView sees
// today's layout; offered less, the ruler stays pinned at the top while the
// lanes scroll under it, and only the rows in view are built. The snapshot
// branch offers the lanes the strip's width, so a 20,000-frame snapshot draws
// names and labels instead of a blank (#219). The lane stack's laziness is
// read from the source, like TimelineStripSafeAreaTests. macOS only.
import Foundation
@testable import SuiteUI
import Testing

@Suite struct TimelineStripLayoutTests {
    @Test func idealHeightIsRulerPlusLanesWithTheToolbarOff() {
        let layout = TimelineStripLayout(trackCount: 3, toolbar: false)
        #expect(layout.idealHeight == SuiteSize.timelineRuler + 3 * SuiteSize.timelineLane)
        // The packet's numbers: a 24 pt ruler over three 32 pt lanes. Typed as
        // CGFloat, since #expect type-checks a bare `24 + 96` on its own as Int.
        let packet: CGFloat = 24 + 3 * 32
        #expect(layout.idealHeight == packet)
    }

    @Test func idealHeightAddsTheToolbarRowWhenOn() {
        let layout = TimelineStripLayout(trackCount: 3, toolbar: true)
        #expect(layout.idealHeight == SuiteSize.timelineRuler + SuiteSize.timelineSlotToolbar + 3 * SuiteSize.timelineLane)
        #expect(layout.toolbarHeight == 36)
    }

    @Test func noTracksIsTheRulerAlone() {
        #expect(TimelineStripLayout(trackCount: 0, toolbar: false).idealHeight == SuiteSize.timelineRuler)
        #expect(TimelineStripLayout(trackCount: -4, toolbar: false).idealHeight == SuiteSize.timelineRuler)
    }

    @Test func theRulerStaysPinnedAfterAScroll() {
        let layout = TimelineStripLayout(trackCount: 300, toolbar: false)
        #expect(layout.rulerFrame(scrollY: 2_000) == 0...24)
        #expect(layout.rulerFrame(scrollY: 0) == 0...24)
        #expect(TimelineStripLayout(trackCount: 300, toolbar: true).rulerFrame(scrollY: 2_000) == 36...60)
    }

    @Test func offeredLessOnlyTheRowsInViewAreBuilt() {
        let layout = TimelineStripLayout(trackCount: 300, toolbar: false)
        let rows = layout.rowsBuilt(offered: 200, scrollY: 2_000)
        #expect(rows.count < 20)
        #expect(rows.count >= 6, "176 pt of 32 pt lanes shows six rows")
        // 2,000 pt down is lane 62 (2,000 / 32 = 62.5).
        #expect(rows.lowerBound == 62)
        #expect(rows.upperBound <= 300)
    }

    @Test func aScrollPastTheEndShowsTheLastRows() {
        let layout = TimelineStripLayout(trackCount: 300, toolbar: false)
        let rows = layout.rowsBuilt(offered: 200, scrollY: 1_000_000)
        #expect(rows.upperBound == 300)
        #expect(rows.count < 20)
        #expect(layout.rowsBuilt(offered: 200, scrollY: -500).lowerBound == 0)
    }

    @Test func offeredTheIdealHeightOrMoreEveryRowIsInView() {
        let layout = TimelineStripLayout(trackCount: 12, toolbar: true)
        #expect(layout.rowsBuilt(offered: layout.idealHeight, scrollY: 0) == 0..<12)
        #expect(layout.rowsBuilt(offered: .infinity, scrollY: 0) == 0..<12)
        #expect(layout.rowsBuilt(offered: .nan, scrollY: .nan) == 0..<12)
        #expect(layout.rowsBuilt(offered: 10, scrollY: 0).isEmpty, "the toolbar and ruler take all 10 pt")
    }

    @Test func theSnapshotBranchOffersTheLanesTheStripsWidth() {
        let layout = TimelineStripLayout(trackCount: 3, toolbar: false)
        // #219: a 20,000-frame timeline at 2 pt per frame is 40,000 pt of lanes.
        #expect(layout.lanesWidth(contentWidth: 40_000, offered: 600, snapshot: true) == 600)
        #expect(layout.lanesWidth(contentWidth: 40_000, offered: 600, snapshot: false) == 40_000 + SuiteSpacing.xl)
        #expect(layout.lanesWidth(contentWidth: 100, offered: 600, snapshot: true) == 600)
        #expect(layout.lanesWidth(contentWidth: 40_000, offered: -1, snapshot: true) == 0)
    }

    @Test func theLaneAndNameStacksAreLazy() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appending(path: "Sources/SuiteUI/TimelineStrip.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
        for function in ["private func lanes(", "private var names:"] {
            let start = try #require(source.range(of: function), "\(function) moved; point this test at it")
            let body = source[start.upperBound...]
            let open = try #require(body.firstIndex(of: "{"))
            let first = body[body.index(after: open)...].trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(first.hasPrefix("LazyVStack("), "\(function) builds every row up front")
        }
    }
}
