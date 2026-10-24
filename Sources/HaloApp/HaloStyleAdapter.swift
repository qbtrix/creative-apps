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

    /// Nil when `id` can run now; else "<title>: <why>".
    func help(_ id: String) -> String? {
        let why = if let model, run != nil {
            model.styleMenuHelp(id, pasted: LayerStylePasteboard.read())
        } else {
            HaloMenuState(project: nil).availability(id).why
        }
        return why.map { "\(HaloProject.styleMenuTitle(id)): \($0)" }
    }

    var body: some View {
        ForEach(ids, id: \.self) { id in
            let why = help(id)
            MenuCommand(HaloProject.styleMenuTitle(id), help: why ?? HaloMenuState.spec(id).summary, isEnabled: why == nil) {
                run?(id)
            }
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
            Button("Done") { onIntent(.show(nil)) }
                .keyboardShortcut(.defaultAction)
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
