// DesignStatusSnapshots.swift: Design's window on the `cards` fixture with A and
// B selected, the status line reading "2 Layers" beside the tool. Writes
// design-status-two-layers-light.png and design-status-two-layers-dark.png.
// macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignStatusSnapshots {
    @Test func twoLayersSelected() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-2")
        model.toggleSelection("node-3")
        #expect(model.selectionCountText == "2 Layers")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignEditor(model: model, zoom: 0.5),
                name: "design-status-two-layers-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
