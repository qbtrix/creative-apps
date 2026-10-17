// DesignSeveralInspectorSnapshots.swift: Design's inspector at the editor's
// panel width with A and B of the `cards` fixture selected (D0-5c): "2 Layers",
// the Align row with Distribute, X, Y and W reading "Mixed" (A is 100, 100,
// 100 × 80 and B 300, 140, 200 × 80) and H reading 80. On `.fake` and on
// `.live`; then Title, a text layer, with its empty Text section after Fill.
// Writes design-inspector-several-fake-, -several-live- and
// -text-{light,dark}.png. Every control the inspector and its Align row show
// lists itself in `suite.controls` with its DesignControlID, enabled exactly
// when the Model's help for it is nil and with that help as its reason; a
// "Mixed" row is text, not a control, so it lists nothing. SwiftUI builds a
// hosting view's accessibility tree only for an assistive client, so the
// inventory stands in for the tooltips. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import SuiteUI

@MainActor
@Suite struct DesignSeveralInspectorSnapshots {
    /// `cards` on `services` with A and B selected.
    private func twoCards(_ services: DesignServices) throws -> DesignWorkspace {
        var model = DesignWorkspace()
        model.useServices(services)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-2")
        model.toggleSelection("node-3")
        #expect(model.selectedNodeIDs == ["node-2", "node-3"])
        return model
    }

    private func shoot(_ state: String, _ model: DesignWorkspace) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PanelSample(model: model), name: "design-inspector-\(state)-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }

    /// The controls the several-layer inspector shows for `model`, each with the Model's help for it.
    private func expectedControls(_ model: DesignWorkspace) -> [ControlEntry] {
        var helps: [(id: String, help: String?)] = DesignAlignEdge.allCases.map {
            (DesignControlID.align($0), model.help(.align($0)))
        }
        helps += DesignDistributeAxis.allCases.map { (DesignControlID.distribute($0), model.help(.distribute($0))) }
        // Only H is shared; X, Y and W read "Mixed" and list nothing.
        helps.append((DesignControlID.frameField(.height), model.styleHelp(.frame)))
        if model.sharedValue(\.fill) != nil { helps.append((DesignControlID.inspectorFill, model.styleHelp(.fill))) }
        return helps.map { ControlEntry(id: $0.id, enabled: $0.help == nil, reason: $0.help) }.sorted { $0.id < $1.id }
    }

    private func registered(_ model: DesignWorkspace) throws -> [ControlEntry] {
        let store = SuiteControlStore()
        _ = try #require(render(PanelSample(model: model).environment(\.suiteControlStore, store), scheme: .light))
        #expect(store.inventory.violations().isEmpty)
        return store.inventory.document().controls
    }

    @Test func severalOnFake() throws {
        let model = try twoCards(.fake)
        #expect(model.selectionCountText == "2 Layers")
        #expect(model.sharedValue { $0.frame.x } == nil)
        #expect(model.sharedValue { $0.frame.y } == nil)
        #expect(model.sharedValue { $0.frame.width } == nil)
        #expect(model.sharedValue { $0.frame.height } == 80)
        let controls = try registered(model)
        #expect(controls == expectedControls(model))
        // Two layers align on `.fake`; Distribute needs three, so it says why.
        #expect(controls.first { $0.id == DesignControlID.align(.left) }?.enabled == true)
        #expect(controls.first { $0.id == DesignControlID.distribute(.horizontal) }?.enabled == false)
        #expect(controls.first { $0.id == DesignControlID.frameField(.height) } != nil)
        #expect(controls.first { $0.id == DesignControlID.frameField(.x) } == nil)
        try shoot("several-fake", model)
    }

    @Test func severalOnLive() throws {
        let model = try twoCards(.live)
        #expect(model.selectionCountText == "2 Layers")
        let controls = try registered(model)
        #expect(controls == expectedControls(model))
        for control in controls where !control.enabled {
            #expect(control.reason?.isEmpty == false, "\(control.id) is disabled without saying why")
        }
        try shoot("several-live", model)
    }

    @Test func titleShowsItsTextSection() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-5")
        #expect(model.selectedNode?.kind == .text)
        let controls = try registered(model)
        #expect(controls.contains { $0.id == DesignControlID.inspectorFill })
        #expect(controls.contains { $0.id == DesignControlID.frameField(.x) })
        try shoot("text", model)
    }
}

private struct PanelSample: View {
    let model: DesignWorkspace
    var body: some View {
        DesignInspector(model: model, perform: { _ in })
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
