// DesignEditorSnapshots.swift: Design's window with its History panel shown
// (design/autosave-history DA-2), on the `cards` fixture after three added
// rectangles: the panel at the trailing edge lists "Open" and the three steps,
// the last current. The panel is DesignHistoryArea's own (`panel`) beside the
// editor, as View > Show History lays it out. Writes
// design-history-panel-light.png and design-history-panel-dark.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignEditorSnapshots {
    @Test func historyPanel() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        for index in 0..<3 {
            try model.addNode(.rectangle, frame: DesignRect(x: 80 + Double(index) * 120, y: 80, width: 96, height: 96), in: "node-1")
        }
        let listing = model.historyListing
        #expect(listing.steps.count == 3 && listing.index == 3)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HStack(spacing: 0) {
                    DesignEditor(model: model, zoom: 0.5)
                    DesignHistoryArea.panel(listing, onJump: { _ in })
                },
                name: "design-history-panel-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
