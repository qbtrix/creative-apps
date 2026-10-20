// DesignTextWidthSnapshots.swift: the Text section's Width chips (canvas-basics
// CB-b, #3337) on the `cards` fixture on `.live`. Title (node-5) switched to
// Fixed width by the chips' commit is one "Change Text Style" step, and the
// section draws with Fixed width picked in
// design-inspector-text-width-{light,dark}.png. The row is listed, enabled, as
// `design.inspector.text-width`. macOS only.
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel
@testable import SuiteUI

@MainActor
@Suite struct DesignTextWidthSnapshots {
    @Test func titleSwitchedToFixedWidth() throws {
        var model = DesignWorkspace()
        model.useServices(.live)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-5")
        #expect(model.findNode("node-5")?.textStyle.fixedWidth == nil)
        var sent: [DesignIntent] = []
        DesignInspectorText(model: model, perform: { sent.append($0) }).commit { $0.fixedWidth = true }
        for intent in sent {
            if case .setStyle(let change) = intent { try model.setStyle(change) }
        }
        #expect(model.findNode("node-5")?.textStyle.fixedWidth == true)
        #expect(model.undoActionName == "Undo Change Text Style")

        let store = SuiteControlStore()
        let view = DesignInspectorText(model: model, perform: { _ in })
        _ = try #require(render(view.environment(\.suiteControlStore, store), scheme: .light))
        let width = store.inventory.document().controls.first { $0.id == DesignControlID.inspectorTextWidth }
        #expect(width?.enabled == true)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                view.frame(width: SuiteSize.editorPanelWidth).padding(SuiteSpacing.xxl),
                name: "design-inspector-text-width-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
