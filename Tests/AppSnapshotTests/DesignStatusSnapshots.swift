// DesignStatusSnapshots.swift: Design's window with two layers selected: the status
// line reads "2 Layers" beside the tool name, the save label is empty and the window
// subtitle is empty (DesignSaveStatus slots). Writes design-status-several-light.png
// and design-status-several-dark.png. macOS only.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignStatusSnapshots {
    @Test func twoLayersSelected() throws {
        var model = DesignFixtures.cards
        model.selectItem("node-2")
        model.toggleSelection("node-3")
        #expect(model.selectionCountText == "2 Layers")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignEditor(model: model, zoom: 0.5),
                name: "design-status-several-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
