// RenderBudgetLibraryLevelsTests.swift: Library's Levels drag on the real
// window (#3633; Tests/render-budgets.md), through the harness
// (RenderBudgetHarness.swift). On the `samples` fixture it opens the first
// cell in the loupe with the cell's "Open" action, switches to Develop and
// drags the Midtones handle (LevelsHandles) 30 pt left over 120 samples at
// 120 Hz, the move that re-renders the loupe preview and its histogram every
// sample. `bodies` gates the window-body count at 0: a Levels sample redraws
// the inspector and the loupe, never the window. The step time is printed and
// judged nowhere (timing rows live in perf-suites). Nested in BodyCountSuites,
// as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryLevelsTests {
        @Test(.timeLimit(.minutes(2))) func bodies() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "samples"]))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return LibraryWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies, turns: 8)
            let first = try #require(w.identifiers().first { $0.hasPrefix(LibraryGrid.cellIdentifierPrefix) })
            #expect(w.perform("Open", on: first), "no Open action on \(first)")
            try await w.settle(500)
            // A synthetic click on the segmented control waits in its tracking loop, so press it the AX way.
            _ = Self.node("library.inspector.develop", in: w.host)?.accessibilityPerformPress?()
            try await w.settle(untilStable: bodies, turns: 8)
            let handle = try #require(await w.element(DevelopInspector.levelsID(.gamma)), "no Midtones handle")
            let drag = try await w.measure("library levels midtones drag, 120 samples", bodies: bodies) {
                try await w.drag(from: CGPoint(x: handle.midX, y: handle.midY), by: CGVector(dx: -30, dy: 0))
            }
            // The edit lands in the inspector and the loupe, never the window body: a sample that reran
            // it would show here. (Hosted SwiftUI elements read no AX value here, #262, so the gamma
            // itself is the journey's to check.)
            #expect(drag.steps == 122, "the drag didn't run: \(drag)")
            expectBodies(drag, atMost: Self.budget, target: 0)
        }

        /// Measured on this branch: 0.
        static let budget = 0

        /// The element called `identifier` under `root`, walking accessibility children and subviews as the
        /// harness does.
        static func node(_ identifier: String, in root: NSView) -> AnyObject? {
            var seen = Set<ObjectIdentifier>()
            func find(_ node: AnyObject, _ depth: Int) -> AnyObject? {
                guard seen.insert(ObjectIdentifier(node)).inserted else { return nil }
                if (node.accessibilityIdentifier?() ?? nil) == identifier { return node }
                guard depth < 60 else { return nil }
                let children = ((node.accessibilityChildren?() ?? nil) ?? []) + ((node as? NSView)?.subviews ?? [])
                for child in children {
                    if let hit = find(child as AnyObject, depth + 1) { return hit }
                }
                return nil
            }
            return find(root, 0)
        }
    }
}
#endif
