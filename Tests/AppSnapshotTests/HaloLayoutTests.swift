// HaloLayoutTests.swift: Halo's layout rules L3 to L5 (blueprint halo 7.3;
// packet docs/blueprints/halo/features/core-loop.md, Quality tests). L3: the
// playhead sits on its frame within 1 pt at frame 0, last / 2 and last, with
// HaloTimelineView hosted at 600, 900 and 1400 pt. L4: the TRANSFORM rows'
// bars align within 0.5 pt, their buttons in one column and no label
// truncated, with HaloLayerInspector at its minimum, ideal and maximum
// widths. L5: the status row (transport left, pills right) overlaps nothing
// and never truncates the timecode at the content minimum. CL-3 adds the
// rules disabled; CL-11 hosts the views and turns them on, and a miss there
// is a `finding` on the view's owner, not a fix in the test. macOS only.
#if canImport(AppKit)
import CoreGraphics
import Testing

@MainActor
@Suite struct HaloLayoutTests {
    /// L3's timeline widths, in points.
    nonisolated static let timelineWidths: [CGFloat] = [600, 900, 1400]
    /// L3: the playhead's distance from its frame's x, at most.
    nonisolated static let playheadTolerance: CGFloat = 1
    /// L4: the TRANSFORM bars' edges across rows, at most.
    nonisolated static let barTolerance: CGFloat = 0.5
    /// L5: the status row's transport and pills overlap, at most.
    nonisolated static let statusOverlap: CGFloat = 0

    /// L3: the playhead on its frame at 600, 900 and 1400 pt (≤ 1 pt).
    @Test(.disabled("waits on CL-11")) func playheadOnItsFrame() {
        Issue.record("L3 isn't written yet (CL-11)")
    }

    /// L4: TRANSFORM bars aligned at the inspector's minimum, ideal and maximum widths (≤ 0.5 pt).
    @Test(.disabled("waits on CL-11")) func transformBarsAlign() {
        Issue.record("L4 isn't written yet (CL-11)")
    }

    /// L5: the status row never overlaps at the content minimum (0 pt).
    @Test(.disabled("waits on CL-11")) func statusRowNeverOverlaps() {
        Issue.record("L5 isn't written yet (CL-11)")
    }
}
#endif
