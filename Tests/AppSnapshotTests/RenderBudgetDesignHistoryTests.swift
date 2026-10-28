// RenderBudgetDesignHistoryTests.swift (design/autosave-history DA-4): the History panel's arrow
// walk on a Design window, through the harness (RenderBudgetHarness.swift). The `cards` fixture
// gets 30 added rectangles, all undone, so the panel shows "Open" current over 30 undone steps,
// and the window is Design's editor with DesignHistoryArea's panel shown, under a view that
// counts its own bodies. A click on "Open" focuses the panel (it jumps nowhere: "Open" is
// current), then 30 Down presses at 120 Hz walk the selection to step 30 without a jump: the
// window and the editor run their bodies at most 3 times (target 0: only the panel and the two
// rows whose selection changed redraw). Keys need a key window, so the harness's window is made
// key-capable (keyCapable), as RenderBudgetHistoryPanelTests does. Nested in BodyCountSuites: it reads global
// body counters. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignHistoryTests {
        static let steps = 30

        @Test(.timeLimit(.minutes(2))) func arrowWalkInThreeBodies() async throws {
            var model = DesignWorkspace()
            model.useServices(.fake)
            let opened = model.openFixture("cards")
            #expect(opened)
            for index in 0..<Self.steps {
                let frame = DesignRect(x: 40 + Double(index % 10) * 120, y: 80 + Double(index / 10) * 120, width: 96, height: 96)
                try model.addNode(.rectangle, frame: frame, in: "node-1")
            }
            for _ in 0..<Self.steps { model.undo() }
            #expect(model.historyListing.index == 0 && model.historyListing.steps.count == Self.steps)
            let w = RenderBudgetWindow(DesignHistoryBudgetWindow(model: model), keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            _ = w.window.makeFirstResponder(w.host)
            let bodies = { () -> Int? in
                #if DEBUG
                return DesignHistoryBudgetWindow.bodyRuns + DesignEditor.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            let open = try #require(await w.element("suite.history.row.0"), "the window shows no History panel")
            w.click(at: CGPoint(x: open.midX, y: open.midY))
            if let panel = RenderBudgetHistoryPanelTests.node("suite.history", in: w.host) { panel.setAccessibilityFocused?(true) }
            try await w.settle(untilStable: bodies)
            let jumped = DesignHistoryBudgetWindow.jumps
            let step = try await w.measure("design history arrow walk, \(Self.steps) steps", bodies: bodies) {
                try await w.ticks(Self.steps) { _ in
                    RenderBudgetHistoryPanelTests.press(NSDownArrowFunctionKey, keyCode: 125, in: w.window)
                }
            }
            _ = await w.element("suite.history.row.\(Self.steps)")
            let last = RenderBudgetHistoryPanelTests.node("suite.history.row.\(Self.steps)", in: w.host)
            #expect(last?.isAccessibilitySelected?() == true, "the arrows didn't walk the selection to step \(Self.steps)")
            #expect(DesignHistoryBudgetWindow.jumps == jumped, "the arrows jumped \(DesignHistoryBudgetWindow.jumps - jumped) times")
            expectBodies(step, atMost: 3, target: 0)
        }
    }
}

/// The counted window: Design's editor with its History panel shown, counting the jumps it is sent.
private struct DesignHistoryBudgetWindow: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif
    // view-static: main-actor
    static var jumps = 0
    let model: DesignWorkspace

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        DesignEditor(model: model, zoom: 0.5)
            .modifier(
                DesignHistoryArea(
                    model: model, jump: { _ in Self.jumps += 1 }, restore: { _, _ in }, onNote: { _ in }, shown: true))
    }
}
#endif
