// HaloControls.swift: every Halo control's id, enabled state and help, for
// the every-control journey (H-J13, QB-F1). A control applies
// `.haloControl(id:enabled:help:)` in its own file: the modifier sets its
// accessibility identifier and adds its entry to HaloControlsKey, a preference
// key, so a control joins the list without touching this file. It also
// registers the control with SuiteUI's `.suiteControl`, so under
// `-SuitePerfProbe` it is in `suite.controls` too: that inventory travels by
// environment and so reaches the toolbar, sidebar and inspector columns,
// which a preference may not leave. Under
// `-HaloControlsProbe` the window root reads the preference and publishes it
// as the `halo.controls` JSON: SuiteUI's ControlDocument, one entry per id
// (the last one placed), sorted by id, as the accessibility label (values can
// read empty, #262) of a hidden element with that identifier, the way
// SuiteUI publishes `suite.controls`. Sheets and menus are separate
// hierarchies, so only controls in the window itself are listed.
import SuiteUI
import SwiftUI

/// The `halo.*` controls placed under a view, in tree order.
struct HaloControlsKey: PreferenceKey {
    static let defaultValue: [ControlEntry] = []

    static func reduce(value: inout [ControlEntry], nextValue: () -> [ControlEntry]) { value += nextValue() }
}

extension View {
    /// Identifies this control as `id` and lists it in `halo.controls`. A
    /// disabled control says why in `help`. A nil `id` lists nothing; with
    /// `identifies` false the view is listed but its parts keep their own
    /// identifiers (see SuiteUI's `suiteControl`).
    func haloControl(id: String?, enabled: Bool, help: String?, identifies: Bool = true) -> some View {
        let entry = id.map { ControlEntry(id: $0, enabled: enabled, reason: enabled ? nil : help) }
        return suiteControl(id: id, enabled: enabled, reason: entry?.reason, identifies: identifies)
            .transformPreference(HaloControlsKey.self) { entries in entry.map { entries.append($0) } }
    }

    /// Lists `entries` in `halo.controls` for a SuiteUI view whose parts identify and
    /// register themselves with `.suiteControl` (the transport).
    func haloControls(_ entries: [ControlEntry]) -> some View {
        transformPreference(HaloControlsKey.self) { $0 += entries }
    }

    /// Publishes the `halo.controls` element over this view when `requested`.
    func haloControlsProbe(_ requested: Bool) -> some View {
        modifier(HaloControlsProbe(requested: requested))
    }
}

/// The History button by the transport (autosave-history HA-2): a
/// button-style toggle that shows and hides the window's History panel
/// (HaloHistoryArea.swift), `halo.history.show`. Outside a Halo window there
/// is no shelf, so it is disabled and says why.
struct HaloHistoryControl: View {
    @Environment(\.haloHistoryShelf) private var shelf

    var body: some View {
        let help: String? = shelf == nil ? "History shows in a Halo window." : nil
        let shown = shelf?.shown == true
        Toggle(isOn: Binding(get: { shown }, set: { shelf?.shown = $0 })) {
            Label("History", systemImage: "clock.arrow.circlepath")
        }
        .toggleStyle(.button)
        .tint(SuiteColor.accent)
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .frame(minWidth: SuiteSize.pillHit, minHeight: SuiteSize.pillHit)
        .contentShape(Rectangle())
        .disabled(help != nil)
        .foregroundStyle(help != nil ? SuiteColor.textTertiary : shown ? SuiteColor.accent : SuiteColor.textSecondary)
        .help(help ?? (shown ? "Hide History" : "Show History"))
        .haloControl(id: "halo.history.show", enabled: help == nil, help: help)
    }
}

private struct HaloControlsProbe: ViewModifier {
    let requested: Bool

    func body(content: Content) -> some View {
        if requested {
            content.backgroundPreferenceValue(HaloControlsKey.self, alignment: .topLeading) { entries in
                ProbeElement("halo.controls", label: SuiteControlInventory(entries: entries).json())
            }
        } else {
            content
        }
    }
}
