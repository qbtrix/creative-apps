// RenderBudgetDesignExportTests.swift: the export sheet's render budget
// (design-export; docs/blueprints/design/features/design-export.md, Quality
// tests) on the real window through the harness (RenderBudgetHarness.swift).
// `sheet`: on `cards` with Desktop selected and the fakes, it opens File >
// Export… (through DesignWindow's DEBUG `openExport` hook: the hosted window has
// no menu bar), picks a format, a scale and a scope chip 3 times each, then
// presses Cancel (`design.export.cancel`). The sheet's run is the export area's
// own state, so the window body runs only for the request: at most 2 bodies over
// the whole walk. `liveRun` times a real run's write and waits on DE-10. The
// sheet is its own window attached to the hosted one, so its controls are found
// from `attachedSheet`'s accessibility tree. Nested in BodyCountSuites, as every
// suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignExportTests {
        @Test(.timeLimit(.minutes(2)))
        func sheet() async throws {
            var model = DesignFixtures.cards
            model.useServices(.fake)
            model.selectItem("node-1")
            let w = RenderBudgetWindow(DesignWindow(seed: model))
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return DesignWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            let chips = [
                "design.export.format.svg", "design.export.format.pdf", "design.export.format.png",
                "design.export.scale.2x", "design.export.scale.3x", "design.export.scale.1x",
                "design.export.scope.page", "design.export.scope.selection", "design.export.scope.frame",
            ]
            var missing: [String] = []
            let walk = try await w.measure("design export sheet: open, 9 picks, cancel", bodies: bodies) {
                try await w.ticks(1) { _ in
                    #if DEBUG
                    DesignWindow.openExport?()
                    #endif
                }
                guard let sheet = await Self.sheet(of: w.window) else { return missing = ["the sheet"] }
                try await w.ticks(chips.count) { i in
                    if let chip = chips.dropFirst(i - 1).first, !Self.press(chip, in: sheet) { missing.append(chip) }
                }
                try await w.ticks(1) { _ in if !Self.press("design.export.cancel", in: sheet) { missing.append("Cancel") } }
            }
            #expect(missing.isEmpty, "nothing to press for \(missing): \(walk)")
            #expect(w.window.attachedSheet == nil, "Cancel left the sheet open")
            // The request is one window body; the sheet's edits are the area's own. Target: 1.
            expectBodies(walk, atMost: 2, target: 1)
        }

        @Test(.disabled("waits on DE-10"), .timeLimit(.minutes(2)))
        func liveRun() async throws {}

        /// The sheet attached to `window`, waiting up to two seconds for SwiftUI to present it.
        static func sheet(of window: NSWindow) async -> NSWindow? {
            for _ in 0..<100 {
                if let sheet = window.attachedSheet { return sheet }
                try? await Task.sleep(for: .milliseconds(20))
            }
            return nil
        }

        /// Presses the element called `identifier` in `window`'s accessibility tree; false when there is none.
        static func press(_ identifier: String, in window: NSWindow) -> Bool {
            node(identifier, in: window)?.accessibilityPerformPress?() ?? false
        }

        /// The first node called `identifier` under `element`, in tree order.
        static func node(_ identifier: String, in element: Any, depth: Int = 0) -> AnyObject? {
            let node = element as AnyObject
            if (node.accessibilityIdentifier?() ?? nil) == identifier { return node }
            guard depth < 60 else { return nil }
            return ((node.accessibilityChildren?() ?? nil) ?? []).lazy
                .compactMap { Self.node(identifier, in: $0, depth: depth + 1) }.first
        }
    }
}
#endif
