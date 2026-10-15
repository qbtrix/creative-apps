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
    /// disabled control says why in `help`.
    func haloControl(id: String, enabled: Bool, help: String?) -> some View {
        let entry = ControlEntry(id: id, enabled: enabled, reason: enabled ? nil : help)
        return suiteControl(id: id, enabled: enabled, reason: entry.reason)
            .transformPreference(HaloControlsKey.self) { $0.append(entry) }
    }

    /// Publishes the `halo.controls` element over this view when `requested`.
    func haloControlsProbe(_ requested: Bool) -> some View {
        modifier(HaloControlsProbe(requested: requested))
    }
}

private struct HaloControlsProbe: ViewModifier {
    let requested: Bool

    func body(content: Content) -> some View {
        if requested {
            content.backgroundPreferenceValue(HaloControlsKey.self, alignment: .topLeading) { entries in
                HaloControlsElement(entries: entries)
            }
        } else {
            content
        }
    }
}

/// The hidden `halo.controls` element: no hits, its label the controls' JSON.
private struct HaloControlsElement: View {
    static let identifier = "halo.controls"
    let entries: [ControlEntry]

    var body: some View {
        Color.clear
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: json))
            .accessibilityIdentifier(Self.identifier)
    }

    /// One entry per id, the last placed, sorted by id; `{}` if it can't encode.
    private var json: String {
        var latest: [String: ControlEntry] = [:]
        for entry in entries { latest[entry.id] = entry }
        let document = ControlDocument(controls: latest.values.sorted { $0.id < $1.id })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(document) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }
}
