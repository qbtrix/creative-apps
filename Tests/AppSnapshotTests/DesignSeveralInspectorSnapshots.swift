// DesignSeveralInspectorSnapshots.swift: Design's inspector at the editor's
// panel width with A and B of the `cards` fixture selected (D0-5c): "2 Layers",
// the Align row with Distribute, X, Y and W reading "Mixed" (A is 100, 100,
// 100 × 80 and B 300, 140, 200 × 80), H reading 80, and Transform's Rotation
// and flips. On `.fake` and on
// `.live`; then Title, a text layer, with its empty Text section after Fill.
// Writes design-inspector-several-fake-, -several-live- and
// -text-{light,dark}.png. Every control the inspector and its Align row show
// (the Fill well's eyedropper too) lists itself in `suite.controls` with its
// id, enabled exactly when the Model's help for it is nil and with that help
// as its reason, a disabled Fill row's eyedropper included; a
// "Mixed" row is text, not a control, so it lists nothing. SwiftUI builds a
// hosting view's accessibility tree only for an assistive client, so the
// inventory stands in for the tooltips. macOS only.
import DesignModel
import SuiteKernel
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
        // Transform: Rotation and the two flips, all with the Model's turn help.
        helps.append((DesignControlID.inspectorRotation, model.turnHelp))
        helps += FlipDirection.allCases.map { (DesignControlID.inspectorFlip($0.rawValue), model.turnHelp) }
        // A shared fill is the color well, which carries the eyedropper with the row's help.
        if model.severalShowFill, model.sharedValue(\.fill) != nil {
            helps.append((DesignControlID.inspectorFill, model.styleHelp(.fill)))
            helps.append(("suite.color.eyedropper", model.styleHelp(.fill)))
        }
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

    /// With style editing not built the Fill row is off, and its eyedropper says so with the row's reason rather
    /// than listing as enabled.
    @Test func offFillTurnsItsEyedropperOff() throws {
        var services = DesignServices.fake
        services.styling = NotBuilt("Style editing")
        let model = try twoCards(services)
        let help = try #require(model.styleHelp(.fill))
        let controls = try registered(model)
        #expect(controls == expectedControls(model))
        let eyedropper = controls.first { $0.id == "suite.color.eyedropper" }
        #expect(eyedropper == ControlEntry(id: "suite.color.eyedropper", enabled: false, reason: help))
    }

    /// One locked layer: its Fill row is off, and the eyedropper says so with the lock's reason.
    @Test func lockedLayersEyedropperSaysWhy() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-2")
        try model.setNodeLocked("node-2", true)
        let help = try #require(model.lockHelp("node-2"))
        let eyedropper = try registered(model).first { $0.id == "suite.color.eyedropper" }
        #expect(eyedropper == ControlEntry(id: "suite.color.eyedropper", enabled: false, reason: help))
    }

    /// Align is two rows of three icon buttons, and several layers add one row of two Distribute
    /// buttons: no title wraps or widens a row (#2421).
    @Test func alignIsCompactIconRows() {
        func height(_ view: some View) -> CGFloat {
            NSHostingView(rootView: view.frame(width: SuiteSize.editorPanelWidth)).fittingSize.height
        }
        let header = height(InspectorSection("Align") { Color.clear.frame(height: SuiteSize.actionButton) })
        let row = SuiteSize.actionButton + SuiteSpacing.xs
        #expect(height(DesignAlignBar(help: [:], perform: { _ in })) == header + row)
        #expect(height(DesignAlignBar(help: [:], distributeHelp: [:], perform: { _ in })) == header + 2 * row)
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
