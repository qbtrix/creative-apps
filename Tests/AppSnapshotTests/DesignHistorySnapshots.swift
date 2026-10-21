// DesignHistorySnapshots.swift (design/autosave-history DA-4): Design's window with the History
// panel shown from the toolbar's History button (DA-3), on the `cards` fixture. After four added
// rectangles the panel lists "Open" and four steps, the last current, and the History button reads
// as selected; after one undo the fourth step is no longer current and the third is. Writes
// design-history-steps-{light,dark}.png and design-history-undo-{light,dark}.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignHistorySnapshots {
    @Test func panelAfterSteps() throws {
        let model = try Self.edited()
        #expect(model.historyListing.index == 4)
        try Self.shoot(model, name: "design-history-steps")
    }

    @Test func panelAfterAnUndo() throws {
        var model = try Self.edited()
        model.undo()
        #expect(model.historyListing.index == 3 && model.historyListing.steps.count == 4)
        try Self.shoot(model, name: "design-history-undo")
    }

    /// The `cards` fixture after four added rectangles.
    static func edited() throws -> DesignWorkspace {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        for index in 0..<4 {
            try model.addNode(.rectangle, frame: DesignRect(x: 80 + Double(index) * 120, y: 80, width: 96, height: 96), in: "node-1")
        }
        return model
    }

    /// The window as the History button lays it out, the panel shown, in light and dark.
    static func shoot(_ model: DesignWorkspace, name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HStack(spacing: 0) {
                    DesignEditor(model: model, zoom: 0.5)
                        .environment(\.designHistory, DesignHistoryShown(isShown: true) {})
                    DesignHistoryArea.panel(model.historyListing, onJump: { _ in })
                },
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
