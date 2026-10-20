// RenderBudgetLibraryLevelsTests.swift: Library's Levels drag on the real
// window (#3633; Tests/render-budgets.md), through the harness
// (RenderBudgetHarness.swift). On the `samples` fixture it opens the first
// cell in the loupe with the cell's "Open" action, switches to Develop and
// steps the Midtones handle (LevelsHandles) 120 times at 120 Hz through its
// adjustable action, each step an edit that re-renders the loupe and its
// histogram. (A synthetic mouse drag on the off-screen window doesn't reach
// the handle's gesture; the journey drags it for real.) `bodies` gates the window-body count at 0: a Levels sample redraws
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
            let id = DevelopInspector.levelsID(.gamma)
            #expect(await w.element(id) != nil, "no Midtones handle")
            var adjustable = false
            let steps = try await w.measure("library levels midtones, 120 steps", bodies: bodies) {
                adjustable = try await w.adjust(id, steps: 120)
            }
            #expect(adjustable, "Midtones isn't adjustable")
            // Each step lands in the inspector and the loupe (a layout pass), never the window body.
            #expect(steps.layouts > 0, "the steps changed nothing: \(steps)")
            expectBodies(steps, atMost: Self.budget, target: 0)
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
