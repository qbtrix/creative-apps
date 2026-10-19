// DesignSnapGuideSnapshots.swift: Design's smart guides on the canvas (snapping SN-7). The `cards`
// fixture with A selected and a fixed guide set pinned for the render (DesignGuidePin), so the
// marks are the overlay's alone: `guides` is a line at x 300 on B's left edge, a 100-point gap
// from A to B and a 28-point gap from the Title down to A; `spacing` is two 100-point spacing
// matches. Each is shot at 50% and 200% zoom, in light and dark: the lines, ticks and pills keep
// one size at either zoom. Writes design-canvas-snap-guides-50-light.png ... and
// design-canvas-snap-spacing-200-dark.png. The value tests pin what `design.canvas.guides` reads.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignSnapGuideSnapshots {
    /// A's right edge on B's left (x 300), the gap A to B, and the gap from the Title's bottom to A.
    static let guides = SnapGuides(
        lines: [SnapLine(axis: .x, at: 300, from: 100, to: 220)],
        gaps: [SnapGap(axis: .x, from: 200, to: 300, across: 150, isSpacing: false),
               SnapGap(axis: .y, from: 72, to: 100, across: 150, isSpacing: false)])

    /// A to B and B to a C moved to x 600: two equal 100-point gaps.
    static let spacing = SnapGuides(
        gaps: [SnapGap(axis: .x, from: 200, to: 300, across: 160, isSpacing: true),
               SnapGap(axis: .x, from: 500, to: 600, across: 160, isSpacing: true)])

    private func shoot(_ guides: SnapGuides, _ name: String) throws {
        var model = DesignFixtures.cards
        model.selectItem("node-2")
        try DesignGuidePin.$guides.withValue(guides) {
            try shootCanvas(model, "\(name)-50", zoom: 0.5)
            try shootCanvas(model, "\(name)-200", zoom: 2)
        }
    }

    @Test func guidesAndGaps() throws {
        #expect(DesignGuideOverlay.value(Self.guides, last: nil) == "x 300, gap x 100, gap y 28")
        #expect(SnapGuideMarks.labels(Self.guides, zoom: 2).map(\.text) == ["100", "28"])
        try shoot(Self.guides, "design-canvas-snap-guides")
    }

    @Test func spacingPills() throws {
        #expect(DesignGuideOverlay.value(Self.spacing, last: nil) == "spacing x 100, spacing x 100")
        #expect(SnapGuideMarks.labels(Self.spacing, zoom: 0.5).map(\.text) == ["100", "100"])
        try shoot(Self.spacing, "design-canvas-snap-spacing")
    }

    @Test func theValueKeepsTheLastSummaryUntilANewPress() {
        // No drag yet: none. A drag reads its guides; one that snaps to nothing reads none.
        #expect(DesignGuideOverlay.value(nil, last: nil) == "none")
        #expect(DesignGuideOverlay.value(.empty, last: nil) == "none")
        #expect(DesignGuideOverlay.value(.fake, last: nil) == "x 300, gap x 100, spacing x 100")
        // After the release the last summary stays; a running drag reads its own guides.
        #expect(DesignGuideOverlay.value(nil, last: "x 300") == "x 300")
        #expect(DesignGuideOverlay.value(.empty, last: "x 300") == "none")
        // The words the overlay keeps at a release.
        #expect(DesignGuideOverlay.words(.fake) == "x 300, gap x 100, spacing x 100")
        #expect(DesignGuideOverlay.words(.empty) == "none")
    }
}
