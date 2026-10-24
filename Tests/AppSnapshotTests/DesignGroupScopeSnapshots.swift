// DesignGroupScopeSnapshots.swift: Design's window on `cards` with A and Title grouped and the group entered
// (Title picked inside it). The status bar shows the "In Group 1" pill, the mouse's way back out: a click on it
// runs Exit Group, which picks the group again and drops the pill. Writes design-group-entered-light.png and
// design-group-entered-dark.png. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import SuiteUI

@MainActor
@Suite struct DesignGroupScopeSnapshots {
    @Test func anEnteredGroupShowsAPillThatExitsIt() throws {
        var model = DesignWorkspace()
        model.useServices(.live)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-2")
        model.toggleSelection("node-5")
        try model.run(.group)
        let group = try #require(model.selectedNodeID)
        model.deselect()
        // A Move press on Title picks the group (as a click does), then Return's command enters it.
        let onTitle = DesignPoint(x: 150, y: 56)
        model.selectTool(.move)
        model.drag(from: onTitle, to: onTitle)
        model.endDrag()
        model.enterGroup()
        #expect(model.groupScopeText == "In Group 1")

        let store = SuiteControlStore()
        let editor = DesignEditor(model: model, zoom: 0.5)
        _ = try #require(render(editor.environment(\.suiteControlStore, store), scheme: .light))
        let pill = store.inventory.document().controls.first { $0.id == DesignControlID.statusGroup }
        #expect(pill?.enabled == true)

        for scheme in [ColorScheme.light, .dark] {
            try snapshot(DesignEditor(model: model, zoom: 0.5),
                         name: "design-group-entered-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
        model.exitGroup()
        #expect(model.selectedNodeIDs == [group] && model.groupScopeText == nil)
    }
}
