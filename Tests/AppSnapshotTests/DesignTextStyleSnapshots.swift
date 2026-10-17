// DesignTextStyleSnapshots.swift: Design's Text rows (style-rows, SR-t) on
// the `cards` fixture on `.live`. Title (node-5) set to 32 pt, Bold, Center
// writes design-inspector-text-style-{light,dark}.png through the whole
// inspector; A (node-2) alone shows the rows after its Fill, disabled with
// "A isn't a text layer." (-text-style-a-{light,dark}.png); Title and A
// together read Title's style and set Title only; the Size field's Return
// commits once, as one "Change Text Style" step, and a drag commits only at
// its end. The intents the view sends are applied as DesignWindow applies
// them. The inventory stands in for the tooltips. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel
@testable import SuiteUI

/// The model a view's intents change, applied as DesignWindow's `perform` does.
@MainActor private final class Recorder {
    var model: DesignWorkspace
    var sent: [DesignIntent] = []

    init(_ model: DesignWorkspace) { self.model = model }

    func perform(_ intent: DesignIntent) {
        sent.append(intent)
        switch intent {
        case .setStyle(let change): try? model.setStyle(change)
        case .endEditRun: model.endEditRun()
        default: break
        }
    }

    var styleSteps: Int { sent.filter { if case .setStyle = $0 { true } else { false } }.count }

    /// The Text rows as they are drawn for the current model, sending here.
    var view: DesignInspectorText { DesignInspectorText(model: model, perform: { [self] in perform($0) }) }
}

private let textIDs = [
    DesignControlID.inspectorTextAlignment, DesignControlID.inspectorTextFamily,
    DesignControlID.inspectorTextSize, DesignControlID.inspectorTextWeight,
]

@MainActor
@Suite struct DesignTextStyleSnapshots {
    /// `cards` on `.live` with `ids` selected, in order.
    private func cards(_ ids: [String]) -> DesignWorkspace {
        var model = DesignWorkspace()
        model.useServices(.live)
        let opened = model.openFixture("cards")
        #expect(opened)
        if let first = ids.first { model.selectItem(first) }
        for id in ids.dropFirst() { model.toggleSelection(id) }
        #expect(model.selectedNodeIDs == ids)
        return model
    }

    /// The Text controls `view` lists, sorted by id.
    private func textControls(_ view: some View) throws -> [ControlEntry] {
        let store = SuiteControlStore()
        _ = try #require(render(view.environment(\.suiteControlStore, store), scheme: .light))
        #expect(store.inventory.violations().isEmpty)
        return store.inventory.document().controls.filter { textIDs.contains($0.id) }.sorted { $0.id < $1.id }
    }

    private func node(_ model: DesignWorkspace, _ id: String) -> DesignNode? { model.findNode(id) }

    @Test func titleAt32BoldCenter() throws {
        let recorder = Recorder(cards(["node-5"]))
        recorder.view.sizeChanged(32, in: TextSizeScrub())
        recorder.view.commit { $0.weight = 700 }
        recorder.view.commit { $0.alignment = .center }
        let style = try #require(recorder.model.sharedValue(\.textStyle))
        #expect(style.size == 32 && style.weight == 700 && style.alignment == .center)
        #expect(recorder.model.undoActionName == "Undo Change Text Style")
        let controls = try textControls(TextPanel(model: recorder.model))
        #expect(controls.map(\.id) == textIDs)
        #expect(controls.allSatisfy { $0.enabled && $0.reason == nil })
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                TextPanel(model: recorder.model),
                name: "design-inspector-text-style-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func rowsAreDisabledOnA() throws {
        let model = cards(["node-2"])
        let help = "A isn't a text layer."
        #expect(model.styleHelp(.textStyle) == help)
        // Through the whole inspector, as J11 finds them, after A's Fill.
        let controls = try textControls(TextPanel(model: model))
        #expect(controls == textIDs.map { ControlEntry(id: $0, enabled: false, reason: help) })
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                TextPanel(model: model),
                name: "design-inspector-text-style-a-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func titleAndASetTitleOnly() throws {
        let recorder = Recorder(cards(["node-5", "node-2"]))
        recorder.view.sizeChanged(32, in: TextSizeScrub())
        // A has no text, so the rows read Title's style, not "Mixed".
        #expect(recorder.view.style?.size == 32)
        let before = node(recorder.model, "node-2")?.textStyle
        recorder.view.commit { $0.weight = 700 }
        #expect(node(recorder.model, "node-5")?.textStyle == DesignTextStyle(
            family: "System", size: 32, weight: 700, alignment: .leading))
        #expect(node(recorder.model, "node-2")?.textStyle == before)
        #expect(recorder.model.undoActionName == "Undo Change Text Style")
    }

    @Test func sizeCommitsOnceOnReturn() throws {
        let recorder = Recorder(cards(["node-5"]))
        _ = try #require(render(recorder.view, scheme: .light))
        // Return in the field sends one change, not dragging: one step.
        recorder.view.sizeChanged(24, in: TextSizeScrub())
        #expect(recorder.styleSteps == 1)
        #expect(node(recorder.model, "node-5")?.textStyle.size == 24)
        // A drag's samples wait; its end commits the last one, once.
        let scrub = TextSizeScrub()
        scrub.dragging = true
        for size in [25.0, 30, 40] { recorder.view.sizeChanged(size, in: scrub) }
        #expect(recorder.styleSteps == 1)
        recorder.view.sizeDragEnded(in: scrub)
        recorder.view.sizeDragEnded(in: scrub)
        #expect(recorder.styleSteps == 2)
        #expect(node(recorder.model, "node-5")?.textStyle.size == 40)
    }
}

/// The whole inspector at the editor's panel width, as the window shows it.
private struct TextPanel: View {
    let model: DesignWorkspace
    var body: some View {
        DesignInspector(model: model, perform: { _ in })
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
