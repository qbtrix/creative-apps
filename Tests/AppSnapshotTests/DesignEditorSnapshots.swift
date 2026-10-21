// DesignEditorSnapshots.swift: Design's window with its History panel shown
// (design/autosave-history DA-2), on the `cards` fixture saved as cards.design,
// then three added rectangles: the panel at the trailing edge lists "Open" with
// the saved dot and the three steps, the last current, under its "History" title
// and "3 steps" (#3945). The editor wears DesignHistoryArea itself, shown, so the
// panel is the window's own trailing inset (#3949): a geometric test holds it
// inside the window, flush at the trailing edge, at the panel width, and clear of
// the editor's columns. Writes design-history-panel-light.png and
// design-history-panel-dark.png. macOS only.
import AppKit
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignEditorSnapshots {
    /// The `cards` fixture saved, then three added rectangles.
    static func edited() throws -> DesignWorkspace {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.didSave(to: URL(fileURLWithPath: "/tmp/cards.design"))
        for index in 0..<3 {
            try model.addNode(.rectangle, frame: DesignRect(x: 80 + Double(index) * 120, y: 80, width: 96, height: 96), in: "node-1")
        }
        return model
    }

    /// The editor as View > Show History lays it out: DesignHistoryArea on it, the panel shown.
    static func window(_ model: DesignWorkspace) -> some View {
        DesignEditor(model: model, zoom: 0.5)
            .modifier(DesignHistoryArea(model: model, jump: { _ in }, restore: { _, _ in }, onNote: { _ in }, shown: true))
    }

    @Test func historyPanel() throws {
        let model = try Self.edited()
        let listing = model.historyListing
        #expect(listing.steps.count == 3 && listing.index == 3)
        #expect(listing.base == "Open" && listing.savedIndex == 0)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(Self.window(model), name: "design-history-panel-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func stepCountReadsInWords() {
        #expect(DesignHistoryArea.stepCount(HistoryListing(base: "Open", steps: [], index: 0)) == "0 steps")
        #expect(DesignHistoryArea.stepCount(HistoryListing(base: "Open", steps: ["Move"], index: 1)) == "1 step")
        #expect(DesignHistoryArea.stepCount(HistoryListing(base: "Open", steps: ["A", "B", "C"], index: 1)) == "3 steps")
    }

    /// #3945: the panel has a header element labelled "History" whose value is the step count.
    @Test(.timeLimit(.minutes(1))) func historyPanelHasTitleAndStepCount() async throws {
        let model = try Self.edited()
        let w = RenderBudgetWindow(DesignHistoryArea.panel(model.historyListing, onJump: { _ in }))
        defer { w.close() }
        try await w.settle()
        #expect(await w.element(DesignHistoryArea.headerID) != nil, "the History panel has no header")
        #expect(w.label(DesignHistoryArea.headerID) == "History")
        let header = BodyCountSuites.RenderBudgetHistoryPanelTests.node(DesignHistoryArea.headerID, in: w.host)
        let raw: Any?? = header?.accessibilityValue?()
        let value = (raw ?? nil) as? String
        #expect(value == "3 steps", "the header's value is \(String(describing: value))")
    }

    /// #3949: at snapshot size the panel sits inside the window, flush at its trailing edge (less
    /// the inset), at the editor panel width, and no column of the editor runs under it. The panel's
    /// element frame is its content's, inside GlassPanel's `SuiteSpacing.l` padding.
    @Test(.timeLimit(.minutes(1))) func historyPanelSitsAtTheTrailingEdge() async throws {
        let model = try Self.edited()
        let size = CGSize(width: 1440, height: 900)
        let w = RenderBudgetWindow(Self.window(model), size: size)
        defer { w.close() }
        try await w.settle()
        let panel = try #require(await w.element(DesignHistoryArea.panelID), "no History panel in the window")
        let bounds = CGRect(origin: .zero, size: size)
        #expect(bounds.insetBy(dx: -0.5, dy: -0.5).contains(panel), "the panel \(panel) leaves the window")
        #expect(abs(panel.width - (SuiteSize.editorPanelWidth - 2 * SuiteSpacing.l)) < 1, "the panel is \(panel.width) wide")
        #expect(abs(panel.maxX - (size.width - SuiteSpacing.s - SuiteSpacing.l)) < 1, "the panel ends at \(panel.maxX)")
        #expect(panel.height > size.height / 2, "the panel is only \(panel.height) tall")
        let columns = await w.splitViews()
        #expect(!columns.isEmpty, "the editor has no split view")
        for split in columns {
            let frame = split.convert(split.bounds, to: nil)
            #expect(frame.maxX <= panel.minX - SuiteSpacing.l + 0.5, "an editor column \(frame) runs under the panel \(panel)")
        }
    }
}
