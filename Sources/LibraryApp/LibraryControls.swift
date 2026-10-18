// LibraryControls.swift: every Library control's id, enabled state and help,
// for the every-control journey (J11, QB-F1). A control applies
// `.libraryControl(id:enabled:help:)` in its own file: the modifier sets its
// accessibility identifier and adds its entry to LibraryControlsKey, a
// preference key, so a control joins the list without touching this file. It
// also registers the control with SuiteUI's `.suiteControl`, so under
// `-SuitePerfProbe` it is in `suite.controls` too: that inventory travels by
// environment and so reaches the toolbar, sidebar and inspector columns,
// which a preference may not leave. A SuiteUI view that draws its own button
// from a ToolbarAction (the empty state's Import Folder…) already identifies
// it from the action's `identifier`; `.libraryControl(action)` only lists it.
// The window root always publishes the `library.controls` JSON: SuiteUI's
// ControlDocument, one entry per id (the last one placed), sorted by id, as
// the accessibility label (values can read empty, #262) of a hidden element
// with that identifier, the way SuiteUI publishes `suite.controls`. It is
// always on, unlike Halo's `-HaloControlsProbe`: J0 reads it on a plain
// launch, and encoding the spine's handful of entries costs nothing next to a
// frame. Sheets and menus are separate hierarchies, so only controls in the
// window itself are listed.
import SuiteUI
import SwiftUI

/// The `library.*` controls placed under a view, in tree order.
struct LibraryControlsKey: PreferenceKey {
    static let defaultValue: [ControlEntry] = []

    static func reduce(value: inout [ControlEntry], nextValue: () -> [ControlEntry]) { value += nextValue() }
}

extension View {
    /// Identifies this control as `id` and lists it in `library.controls`. A
    /// disabled control says why in `help`.
    func libraryControl(id: String, enabled: Bool, help: String?) -> some View {
        let entry = ControlEntry(id: id, enabled: enabled, reason: enabled ? nil : help)
        return suiteControl(id: id, enabled: enabled, reason: entry.reason)
            .transformPreference(LibraryControlsKey.self) { $0.append(entry) }
    }

    /// Lists `action` in `library.controls` when it has an identifier; the
    /// SuiteUI view that draws its button identifies and registers it.
    func libraryControl(_ action: ToolbarAction) -> some View {
        let entry = action.controlEntry()
        return transformPreference(LibraryControlsKey.self) { if let entry { $0.append(entry) } }
    }

    /// Publishes the `library.controls` element over this view.
    func libraryControlsProbe() -> some View {
        backgroundPreferenceValue(LibraryControlsKey.self, alignment: .topLeading) { entries in
            ProbeElement("library.controls", label: SuiteControlInventory(entries: entries).json())
        }
    }
}
