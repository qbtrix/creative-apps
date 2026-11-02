// RenderBudgetAnchorTests.swift (anchor-parenting AN-6, the packet's budget
// row): a 120-sample drag of the anchor mark on the gallery's `anchor` page in
// a real 1280 x 820 window runs the window body at most 3 times. The mark
// keeps the drag in its own state and the page sends one
// `transform.set-anchor` at release, so the samples never reach the window.
// The drag lands Box 1's anchor on its top left corner and the mark moves
// there. p95 ≤ 8 ms is report-only: `measure` prints the step's p95, and a
// gated timing row waits for the supervisor's perf list. Nested in
// BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

/// The window's root, counting its bodies; the boxes and the mark live in the page under it.
private struct AnchorBudgetPage: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        GalleryAnchorPage()
    }
}

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetAnchorTests {
        private static let bodies = { () -> Int? in
            #if DEBUG
            return AnchorBudgetPage.bodyRuns
            #else
            return nil
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func anchorDragInThreeBodies() async throws {
            let w = RenderBudgetWindow(AnchorBudgetPage())
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            let mark = try #require(await w.element("suite.anchor.mark"), "no anchor mark on the page")
            let start = CGPoint(x: mark.midX, y: mark.midY)
            // Box 1's anchor is its centre, 60 x 40 from its top left corner; window points are y-up.
            let step = try await w.measure("anchor mark drag, 120 samples", bodies: Self.bodies) {
                try await w.drag(from: start, by: CGVector(dx: -60, dy: 40))
            }
            expectBodies(step, atMost: 3, target: 1)
            try await w.settle()
            let moved = try #require(await w.element("suite.anchor.mark"), "no anchor mark after the drag")
            #expect(abs(moved.midX - (start.x - 60)) <= 2 && abs(moved.midY - (start.y + 40)) <= 2,
                    "the mark went from \(start) to \(moved), not to Box 1's top left corner")
        }
    }
}
#endif
