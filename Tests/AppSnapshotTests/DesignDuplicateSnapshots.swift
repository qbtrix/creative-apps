// DesignDuplicateSnapshots.swift: Object > Duplicate on `cards` (#414). A selected, then Duplicate:
// the editor shows A where it was and its copy at +10, +10, selected, with its own row in Layers
// right above A's. Writes design-duplicate-light.png and -dark.png. `shootEditor` (the whole
// editor at half zoom) is shared by DesignGroupSnapshots and DesignPasteboardSnapshots.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

/// Writes `<name>-light.png` and `<name>-dark.png`: the whole editor on `model` at half zoom.
@MainActor
func shootEditor(_ model: DesignWorkspace, _ name: String) throws {
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(
            DesignEditor(model: model, zoom: 0.5), name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
    }
}

@MainActor
@Suite struct DesignDuplicateSnapshots {
    @Test func originalAndCopy() throws {
        var model = DesignFixtures.cards
        model.selectItem("node-2")
        try model.run(.duplicate)

        let desktop = try #require(model.selectedPage?.nodes.first)
        let a = try #require(desktop.children.first { $0.id == "node-2" })
        let copy = try #require(model.selectedNode)
        #expect(a.frame == DesignRect(x: 100, y: 100, width: 100, height: 80))
        #expect(copy.id != a.id)
        #expect(copy.name == "A")
        #expect(copy.frame == DesignRect(x: 110, y: 110, width: 100, height: 80))
        // Directly above the original: the next row in back-to-front order.
        let ids = desktop.children.map(\.id)
        #expect(ids.firstIndex(of: copy.id) == ids.firstIndex(of: a.id).map { $0 + 1 })
        #expect(model.undoActionName == "Undo Duplicate")
        try shootEditor(model, "design-duplicate")
    }
}
