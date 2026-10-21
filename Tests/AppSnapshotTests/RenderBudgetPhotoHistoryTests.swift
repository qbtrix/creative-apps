// RenderBudgetPhotoHistoryTests.swift (history-panel PH-4, quality row
// "render: arrow-key walk down 30 steps of the tab on a 12 MP image"): the
// real Photo window on the `large` fixture (4000 x 3000) with 30 brush steps,
// jumped back to "Open", its inspector on the History tab, hosted on the
// render budget harness (RenderBudgetHarness.swift). Thirty Down presses at
// 120 Hz walk the tab's selection from "Open" to step 30 without a jump: the
// image stays at "Open", and PhotoEditor's body (the window body, a debug-only
// counter) runs at most 3 times (target 0: only the panel and the two rows
// whose selection changed redraw). The p95 (packet: ≤ 16 ms) is printed, not
// gated: a step-time budget belongs in a Tests/perf-suites.txt test, which
// only the supervisor lists. Keys need a key window, so the harness builds a
// key-capable one (`keyCapable: true`, never a class swap), the panel is focused by a click on "Open" (the current
// state, so it jumps nowhere), and the presses go through the window as
// RenderBudgetHistoryPanelTests sends them. Nested in BodyCountSuites: it
// reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import CoreRaster
import PhotoModel
import SuiteKernel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoHistoryTests {
        static let steps = 30

        @Test(.timeLimit(.minutes(2))) func arrowWalkInThreeBodies() async throws {
            let w = RenderBudgetWindow(PhotoWindow(model: try Self.document()), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            _ = w.window.makeFirstResponder(w.host)
            let bodies = { BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(1000)
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)
            send(.history(.showTab(.history)))
            try await w.settle()
            let open = try #require(await w.element("suite.history.row.0"), "the History tab shows no Open row")
            w.click(at: CGPoint(x: open.midX, y: open.midY))
            if let panel = Panel.node("suite.history", in: w.host) { panel.setAccessibilityFocused?(true) }
            try await w.settle()
            #expect(edited.workspace?.historyIndex == 0, "the click on Open moved the image")

            let step = try await w.measure("photo history tab arrow walk, \(Self.steps) steps, 12 MP", bodies: bodies) {
                try await w.ticks(Self.steps) { _ in Panel.press(NSDownArrowFunctionKey, keyCode: 125, in: w.window) }
            }
            _ = await w.element("suite.history.row.\(Self.steps)")
            let last = Panel.node("suite.history.row.\(Self.steps)", in: w.host)
            #expect(last?.isAccessibilitySelected?() == true, "the arrows didn't walk the selection to step \(Self.steps)")
            #expect(edited.workspace?.historyIndex == 0, "the arrows jumped the image")
            #expect(edited.workspace?.historyListing.steps.count == Self.steps, "the walk changed the step count")
            expectBodies(step, atMost: 3, target: 0)
        }

        /// The shared HistoryPanel budget suite's key presses and accessibility walk.
        private typealias Panel = BodyCountSuites.RenderBudgetHistoryPanelTests

        /// The `large` fixture (4000 x 3000) with `steps` short brush strokes, jumped back to "Open".
        static func document() throws -> PhotoWorkspace {
            var model = try PhotoWorkspace.fixture(.large)
            model.selectTool(.brush)
            model.setToolOption(.size(16))
            for i in 0..<steps {
                let y = Double(100 + i * 90)
                model.drag(from: Mask.Point(x: 200, y: y), to: Mask.Point(x: 200, y: y))
                model.drag(from: Mask.Point(x: 200, y: y), to: Mask.Point(x: 600, y: y))
                model.endDrag()
            }
            model.jumpToHistoryStep(0)
            return model
        }
    }
}

#endif
