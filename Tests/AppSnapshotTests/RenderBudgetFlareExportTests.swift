// RenderBudgetFlareExportTests.swift: the export sheet's render budget
// (flare-export FX-5; docs/blueprints/flare/features/flare-export.md, Quality
// tests) on the real window through the harness (RenderBudgetHarness.swift).
// On `showcase` with the fakes it presses the toolbar's Export…, picks the PNG
// sequence chip, steps the To row (`flare.export.to`) 60 times the way
// VoiceOver and XCUI adjust it (down and up in turn, so each step stays in the
// scene's 48 frames and is an edit), then presses Cancel (`flare.export.cancel`).
// The sheet is its own window attached to the hosted one, so its controls are
// found from `attachedSheet`'s accessibility tree, not the host's. Export… is
// a toolbar item, so the harness window gets a title bar and an NSToolbar the
// host bridges its toolbar into. `bodies`
// gates the window-body counts; `timing` (report-only, for
// Tests/perf-suites.txt) judges the To steps. Nested in BodyCountSuites, as
// every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFlareExportTests {
        @Test(.timeLimit(.minutes(2)))
        func bodies() async throws {
            let (open, to, close) = try await Self.run()
            // The sheet opening is the press and the run's begin: two bodies at most. Target: 2.
            expectBodies(open, atMost: 2, target: 2)
            // Each To step is one options edit: one body. Target: 60.
            expectBodies(to, atMost: 60, target: 60)
            // Cancel on the editing sheet is the dismiss and the sheet going: two bodies at most. Target: 2.
            expectBodies(close, atMost: 2, target: 2)
        }

        @Test(.timeLimit(.minutes(2)))
        func timing() async throws {
            let (_, to, _) = try await Self.run()
            // Target: a step fits one 120 Hz frame.
            expectP95(to, atMost: 20, target: 8.3)
        }

        static func run() async throws -> (open: RenderStep, to: RenderStep, close: RenderStep) {
            let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "showcase"]))
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            // Export… is a toolbar item: the window gets a title bar and the host bridges its toolbar
            // into it, which only happens as the host joins the window.
            w.window.styleMask.insert(.titled)
            w.window.contentView = nil
            w.host.sceneBridgingOptions = [.toolbars]
            w.window.toolbar = NSToolbar()
            w.window.contentView = w.host
            let bodies = { () -> Int? in
                #if DEBUG
                return FlareWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            var pressed = false
            let open = try await w.measure("flare export sheet opens", bodies: bodies) {
                // The toolbar item's viewer acts on the press but answers false: the sheet is the check.
                try await w.ticks(1) { _ in
                    let item = Self.node("flare.export.showSheet", in: w.window)
                    pressed = item != nil
                    _ = item?.accessibilityPerformPress?()
                }
            }
            #expect(pressed, "no Export… (flare.export.showSheet) to press")
            let sheet = try #require(await Self.sheet(of: w.window), "Export… opened no sheet: \(open)")
            #expect(Self.press("flare.export.format.pngSequence", in: sheet), "no PNG sequence chip")
            try await w.settle(untilStable: bodies)
            let row = try #require(Self.node("flare.export.to", in: sheet), "no To row (flare.export.to)")
            let to = try await w.measure("flare export To row, 60 steps", bodies: bodies) {
                try await w.ticks(60) { i in
                    _ = i.isMultiple(of: 2) ? row.accessibilityPerformIncrement?() : row.accessibilityPerformDecrement?()
                }
            }
            #expect((to.bodies ?? 1) >= 1, "the To row didn't step: \(to)")
            let close = try await w.measure("flare export sheet closes", bodies: bodies) {
                try await w.ticks(1) { _ in pressed = Self.press("flare.export.cancel", in: sheet) }
            }
            #expect(pressed, "no Cancel (flare.export.cancel) to press")
            #if DEBUG
            #expect(FlareWindow.shownModel?.exportingOptions == nil, "Cancel left the run open: \(close)")
            #endif
            return (open, to, close)
        }

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

        /// The first node called `identifier` under `element`, in tree order (read as AnyObject: SwiftUI's
        /// nodes answer the NSAccessibility methods informally).
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
