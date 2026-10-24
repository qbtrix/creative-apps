// HaloStyleAdapter.swift (layer-styles HY-2): adapters onto SuiteUI for the styling area. HaloStyleMenuItems
// is one MenuCommand per Layer menu style id, titled and disabled by the Model; HaloStyleSheet is LayerStylePanel
// over Done (Return), until LS-3 gives the panel its own; HaloStyleSheetHost presents it while `stylePanel` is set.
// Views only read HaloProject and call its methods.
import HaloModel
import SuiteImaging
import SuiteUI
import SwiftUI

/// The Layer menu's four style items for the focused project; disabled with "<title>: <why>" while one can't run.
struct HaloStyleMenuItems: View {
    let model: HaloProject?
    let run: (@MainActor (String) -> Void)?

    var ids: [String] { HaloProject.styleMenuIDs }

    /// What the items read: the project while there is a window to send to, and the pasteboard's style.
    var state: HaloStyleMenuState {
        HaloStyleMenuState(project: run == nil ? nil : model, pasted: LayerStylePasteboard.read())
    }

    /// Nil when `id` can run now; else "<title>: <why>".
    func help(_ id: String) -> String? { state.why(id).map { "\(HaloProject.styleMenuTitle(id)): \($0)" } }

    var body: some View {
        ForEach(ids, id: \.self) { id in
            MenuCommand(HaloStyleMenuState.spec(id), on: state) { run?(id) }
        }
    }
}

/// The style panel sheet: LayerStylePanel at the open section over Done.
struct HaloStyleSheet: View {
    let model: HaloProject
    let onIntent: (StyleIntent) -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: SuiteSpacing.s) {
            LayerStylePanel(
                style: model.styleSelection, selected: model.stylePanel ?? .dropShadow, help: model.styleHelp,
                onIntent: onIntent)
            MenuCommand(HaloStyleMenuState.done, on: HaloStyleMenuState(project: model, pasted: nil),
                        shortcut: .defaultAction) { onIntent(.show(nil)) }
                .accessibilityIdentifier("halo.style.done")
        }
        .padding(SuiteSpacing.m)
    }
}

/// Presents HaloStyleSheet while the project's `stylePanel` is set; dismissing it closes the panel.
struct HaloStyleSheetHost: ViewModifier {
    let model: HaloProject
    let onIntent: (StyleIntent) -> Void

    func body(content: Content) -> some View {
        content.sheet(isPresented: Binding(get: { model.stylePanel != nil }, set: { if !$0 { onIntent(.show(nil)) } })) {
            HaloStyleSheet(model: model, onIntent: onIntent)
        }
    }
}
