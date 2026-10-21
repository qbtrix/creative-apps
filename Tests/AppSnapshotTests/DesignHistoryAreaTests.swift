// DesignHistoryAreaTests.swift (design/autosave-history DA-3): the History panel's wiring on a
// Design window. A row click goes out as exactly one jump intent, and the stub's refusal reaches
// the status line as its reason; the toolbar's History button toggles the panel, shows it as
// selected while it is shown, and is off with its reason with no file or no panel to show; the
// panel shown by DesignHistoryArea is on screen and hidden is not; and the panel follows undo
// and redo, its current row moving with the listing's index. A jump that lands needs DA-5's
// adapter bodies, so that test stays disabled. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteKernel
import SwiftUI
import Testing

@testable import DesignApp
@testable import SuiteUI

/// What the panel and the button sent, for the tests to count.
@MainActor private final class Sent {
    var jumps: [Int] = []
    var notes: [String] = []
    var toggles = 0
}

@MainActor
@Suite struct DesignHistoryAreaTests {
    /// The `cards` fixture after `steps` added rectangles.
    static func edited(_ steps: Int) throws -> DesignWorkspace {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        for index in 0..<steps {
            try model.addNode(
                .rectangle, frame: DesignRect(x: 40 + Double(index % 10) * 120, y: 80 + Double(index / 10) * 120, width: 96, height: 96),
                in: "node-1")
        }
        return model
    }

    @Test func rowClickEmitsOneJumpIntent() throws {
        let model = try Self.edited(3)
        let sent = Sent()
        let panel = HistoryPanel(listing: model.historyListing) { index in
            DesignHistoryArea.jump(index, with: { sent.jumps.append($0) }, onNote: { sent.notes.append($0) })
        }
        panel.click(1)
        #expect(sent.jumps == [1], "a click on step 1 sent \(sent.jumps)")
        #expect(sent.notes.isEmpty)
        panel.click(9)
        #expect(sent.jumps == [1], "a click past the rows jumped")
    }

    @Test func refusedJumpShowsItsReason() throws {
        var model = try Self.edited(3)
        let sent = Sent()
        DesignHistoryArea.jump(1, with: { try model.jumpHistory(to: $0) }, onNote: { sent.notes.append($0) })
        #expect(sent.notes == [DesignRefusal.notBuilt("History").help])
        #expect(model.historyListing.index == 3, "a refused jump moved the history")
    }

    @Test(.disabled("DA-5 writes the adapter bodies")) func rowClickLandsOnTheStep() throws {
        var model = try Self.edited(3)
        try model.jumpHistory(to: 1)
        #expect(model.historyListing.index == 1)
        #expect(model.historyListing.steps.count == 3, "the jump recorded a step")
    }

    @Test func toolbarButtonTogglesThePanel() throws {
        let model = try Self.edited(1)
        let sent = Sent()
        let hidden = DesignHistoryArea.toolbarAction(model, DesignHistoryShown(isShown: false) { sent.toggles += 1 })
        #expect(hidden.identifier == DesignToolbarItem.history.identifier)
        #expect(hidden.isEnabled && !hidden.isSelected)
        hidden.perform()
        #expect(sent.toggles == 1, "one click toggled \(sent.toggles) times")
        let shown = DesignHistoryArea.toolbarAction(model, DesignHistoryShown(isShown: true) { sent.toggles += 1 })
        #expect(shown.isEnabled && shown.isSelected)
        shown.perform()
        #expect(sent.toggles == 2)
    }

    @Test func toolbarButtonSaysWhyItIsOff() {
        let closed = DesignHistoryArea.toolbarAction(DesignWorkspace(), DesignHistoryShown(isShown: false) {})
        #expect(closed.unavailableHelp == DesignToolbarItem.history.unavailableHelp(in: DesignWorkspace()))
        #expect(!closed.isEnabled)
        var open = DesignWorkspace()
        open.useServices(.fake)
        _ = open.openFixture("cards")
        let alone = DesignHistoryArea.toolbarAction(open, nil)
        #expect(alone.unavailableHelp == DesignHistoryArea.noPanel)
    }

    @Test(.timeLimit(.minutes(1))) func shownPanelIsOnScreen() async throws {
        let model = try Self.edited(2)
        for shown in [true, false] {
            let w = RenderBudgetWindow(
                DesignEditor(model: model, zoom: 0.5)
                    .modifier(DesignHistoryArea(model: model, jump: { _ in }, restore: { _, _ in }, onNote: { _ in }, shown: shown)))
            defer { w.close() }
            try await w.settle()
            let row = await w.element("suite.history.row.2")
            #expect((row != nil) == shown, "the panel \(shown ? "doesn't show" : "shows") with shown \(shown)")
        }
    }

    @Test(.timeLimit(.minutes(1))) func panelFollowsUndoAndRedo() async throws {
        var model = try Self.edited(3)
        let w = RenderBudgetWindow(AnyView(DesignHistoryArea.panel(model.historyListing, onJump: { _ in })))
        defer { w.close() }
        try await w.settle()
        #expect(Self.selected(3, in: w.host), "step 3 isn't current after three edits")
        model.undo()
        #expect(model.historyListing.index == 2)
        w.host.rootView = AnyView(DesignHistoryArea.panel(model.historyListing, onJump: { _ in }))
        try await w.settle()
        #expect(Self.selected(2, in: w.host), "the panel didn't follow the undo to step 2")
        model.redo()
        #expect(model.historyListing.index == 3)
        w.host.rootView = AnyView(DesignHistoryArea.panel(model.historyListing, onJump: { _ in }))
        try await w.settle()
        #expect(Self.selected(3, in: w.host), "the panel didn't follow the redo to step 3")
    }

    /// Whether row `position` is the panel's selected row.
    static func selected(_ position: Int, in host: NSView) -> Bool {
        let node = BodyCountSuites.RenderBudgetHistoryPanelTests.node("suite.history.row.\(position)", in: host)
        return node?.isAccessibilitySelected?() == true
    }
}
#endif
