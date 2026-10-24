// HaloWindow+Styling.swift (layer-styles HY-2): the styling area's hook. Layer > Layer Style…, Copy, Paste and
// Clear Layer Style are HaloStyleMenuItems, one MenuCommand per id in `HaloProject.styleMenuIDs`, titled and
// disabled by the Model (`styleMenuTitle`, `styleMenuHelp`), so an item whose kernel body is still a stub says so.
// The window publishes `runStyleMenu` as the `haloRunStyleMenu` focused value: it runs the id on the project and
// puts what Copy returns on LayerStylePasteboard, which Paste reads. `stylingScene(_:)` presents HaloStyleSheet
// while `stylePanel` is set: SuiteUI's LayerStylePanel at that section, each gesture sent to `runStyle`, and
// Done (Return) closing it, until LS-3 gives the panel its own. Views only read HaloProject and call its methods.
import HaloModel
import SuiteImaging
import SuiteUI
import SwiftUI

extension FocusedValues {
    /// Runs one Layer menu style id on the focused Halo window; nil with no Halo window.
    @Entry var haloRunStyleMenu: (@MainActor (String) -> Void)?
}

extension HaloWindow {
    func stylingScene(_ content: some View) -> some View {
        content
            .modifier(HaloStyleSheetHost(model: model, onIntent: { intent in
                takePlayback()
                model.runStyle(intent)
            }))
            .focusedSceneValue(\.haloRunStyleMenu, runStyleMenu)
    }

    /// Runs `id`'s Layer menu item; Copy's style goes on the pasteboard.
    func runStyleMenu(_ id: String) {
        takePlayback()
        let copied = model.runStyleMenu(id, pasted: LayerStylePasteboard.read())
        if id == "style.copy", let copied { LayerStylePasteboard.write(copied) }
    }
}

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
