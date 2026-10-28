// RenderBudgetPenPathsTests.swift (pen-paths PN-4, quality rows "render:
// anchor drag" and "render: marquee over 5,000 anchors"): what Direct
// Selection costs in a real 1280 x 820 window. The window hosts
// PathEditOverlay on an artboard the way the gallery's `pen-paths` page does,
// in a child page that owns the path and selection and applies each select
// and move, and counts the window's own bodies: a 120-sample drag of the
// sample's first anchor, and a 120-sample marquee over 5,000 anchors (half
// selected). `bodies` gates that each runs at most 3 window bodies (target 0:
// only the page and the overlay redraw) and lands its select and move;
// `timing` (Tests/perf-suites.txt, report-only) judges each p95 step within
// 8 ms. Until PN-5 the kernel's AnchorEdit.moved returns its input, so the
// drag proves the moves reach the page, not that the anchor moved. The page
// opts in to activation clicks, as a test process's every press is one.
// Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPenPathsTests {
        @Test(.timeLimit(.minutes(2))) func bodies() async throws {
            let (drag, marquee) = try await (Self.anchorDrag(), Self.marquee())
            expectBodies(drag, atMost: 3, target: 0)
            expectBodies(marquee, atMost: 3, target: 0)
        }

        @Test(.timeLimit(.minutes(2))) func timing() async throws {
            let (drag, marquee) = try await (Self.anchorDrag(), Self.marquee())
            expectP95(drag, atMost: 8, target: 8)
            expectP95(marquee, atMost: 8, target: 8)
        }

        /// A 120-sample drag of the sample's first anchor, which selects it and moves it.
        static func anchorDrag() async throws -> RenderStep {
            let w = RenderBudgetWindow(PenPathsBudgetWindow(path: GalleryPenPaths.sample, artboard: SuiteSize.contentMinimum))
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            let box = try #require(await w.element("suite.gallery.pen-canvas"), "no artboard (suite.gallery.pen-canvas)")
            let start = w.point(CGPoint(x: 260, y: 80), on: SuiteSize.contentMinimum, in: box)
            let step = try await w.measure("pen-paths anchor drag, 120 samples", bodies: Self.bodies) {
                try await w.drag(from: start, by: CGVector(dx: 60, dy: -40))
            }
            let state = await Self.state(in: w) { $0.hasPrefix("1 selected") && !$0.hasSuffix(" 0 moves") }
            #expect(state?.hasPrefix("1 selected") == true && state?.hasSuffix(" 0 moves") == false,
                    "the drag didn't select and move the anchor: \(state ?? "no state")")
            return step
        }

        /// A 120-sample marquee over 5,000 anchors, half selected, which replaces the selection.
        static func marquee() async throws -> RenderStep {
            let stars = PenPathsFixture.stars()
            let w = RenderBudgetWindow(PenPathsBudgetWindow(path: stars, artboard: PenPathsFixture.artboard,
                                                            selection: PenPathsFixture.half(stars)))
            defer { w.close() }
            try await w.settle(untilStable: Self.bodies)
            let box = try #require(await w.element("suite.gallery.pen-canvas"), "no artboard (suite.gallery.pen-canvas)")
            let start = w.point(CGPoint(x: 4, y: 4), on: PenPathsFixture.artboard, in: box)
            let end = w.point(CGPoint(x: 470, y: 380), on: PenPathsFixture.artboard, in: box)
            let step = try await w.measure("pen-paths marquee over 5,000 anchors, 120 samples", bodies: Self.bodies) {
                try await w.drag(from: start, by: CGVector(dx: end.x - start.x, dy: end.y - start.y))
            }
            let state = await Self.state(in: w) { !$0.hasPrefix("2500 selected") }
            #expect(state.map { !$0.hasPrefix("2500 selected") && !$0.hasPrefix("0 selected") } == true,
                    "the marquee didn't replace the selection with the anchors inside it: \(state ?? "no state")")
            return step
        }

        private static func bodies() -> Int? {
            #if DEBUG
            return PenPathsBudgetWindow.bodyRuns
            #else
            return nil
            #endif
        }

        /// The page's "N selected, M moves" probe, waiting up to two seconds for `done`.
        private static func state(in w: RenderBudgetWindow<PenPathsBudgetWindow>, until done: (String) -> Bool) async -> String? {
            var label: String?
            for _ in 0..<100 {
                label = w.label("suite.budget.pen-state")
                if let label, done(label) { return label }
                try? await Task.sleep(for: .milliseconds(20))
            }
            return label
        }
    }
}

/// The counted window: a header over the page, which owns the path and selection.
private struct PenPathsBudgetWindow: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif
    let path: PathInEdit, artboard: CGSize
    var selection = Selection<AnchorRef>()

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Direct Selection").font(SuiteFont.sectionCaps).foregroundStyle(SuiteColor.secondaryText)
            PenPathsBudgetPage(path: path, selection: selection, artboard: artboard)
        }
        .allowsWindowActivationEvents()
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The gallery page's artboard in Direct Selection: selects (by ref or in the marquee) and moves applied to its state.
private struct PenPathsBudgetPage: View {
    @State var path: PathInEdit
    @State var selection: Selection<AnchorRef>
    let artboard: CGSize
    @State var moves = 0

    var body: some View {
        SuiteColor.artboard
            .frame(width: artboard.width, height: artboard.height)
            .overlay(alignment: .topLeading) {
                PathEditOverlay(draft: nil, path: path, selection: selection, tool: .directSelect, zoom: 1) { apply($0) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("suite.gallery.pen-canvas")
            .overlay {
                ProbeElement("suite.budget.pen-state", label: "\(selection.ordered.count) selected, \(moves) moves",
                             size: CGSize(width: 1, height: 1))
            }
    }

    private func apply(_ intent: PathIntent) {
        switch intent {
        case let .select(anchors, rect, extend):
            let picked = anchors ?? rect.map { AnchorIndex(path.path, toDocument: path.toDocument).inside($0) } ?? []
            selection.replace(extend ? selection.ordered + picked.filter { !selection.contains($0) } : picked)
        case let .move(dx, dy, _):
            path.path = AnchorEdit.moved(path.path, selection.set, dx: dx, dy: dy)
            moves += 1
        default: break
        }
    }
}
#endif
