// SegmentedTabs.swift: the tab switch at the top of an editor's right panel
// (Adjust | Layers), a system segmented Picker filling the panel's width on a
// flat band that ends in a hairline. It draws as a capsule (docs/design.md,
// Tabs): a `row` capsule with 2 pt padding round `chip`-tall segments, the
// selected one on the `stateSelected` tint, the capsule on `rowHover` under
// the pointer and at 40% while disabled. It stays a `Picker` underneath, so
// the system draws the segments, Tab reaches it and VoiceOver reads it as one.
// A selection change fades over 0.14 s (at once under `suiteReduceMotion`)
// and reports a `fade-start`/`fade-end` pair on series `tabs` (QB-S9;
// TabsProbe, which a probe host sets). Given an `id` it lists itself in
// `suite.controls`, its reason while unavailable being its tooltip
// (`entry`). Value in, `onChange` out: the host keeps which tab is showing
// as its own presentation state. Owns presentation state only: hover and the
// selection drawn while it fades.
import SwiftUI

public struct SegmentedTabs<ID: Hashable & Sendable>: View {
    private let label: String
    private let tabs: [InspectorOption<ID>]
    private let selection: ID
    private let id: String?
    private let unavailableHelp: String?
    private let onChange: @MainActor (ID) -> Void
    /// The selection drawn; it follows `selection` through TabsProbe.fade, so the fade reports its marks.
    @State private var shown: ID
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.suiteReduceMotion) private var reduceMotion
    @Environment(\.tabsProbe) private var probe
    @Environment(\.tabsHover) private var forcedHover

    /// `label` names the switch for VoiceOver and is its tooltip; it is not
    /// drawn. `id` lists it in `suite.controls`; `unavailableHelp` disables
    /// it and says why, as its tooltip and its entry's reason.
    public init(
        _ label: String, tabs: [InspectorOption<ID>], selection: ID, id: String? = nil,
        unavailableHelp: String? = nil, onChange: @escaping @MainActor (ID) -> Void
    ) {
        self.label = label
        self.tabs = tabs
        self.selection = selection
        self.id = id
        self.unavailableHelp = unavailableHelp
        self.onChange = onChange
        _shown = State(initialValue: selection)
    }

    /// The tooltip: the switch's name, or why it can't act.
    nonisolated public static func help(_ label: String, unavailable: String? = nil) -> String {
        unavailable ?? label
    }

    /// The `suite.controls` entry under `id`: while disabled its reason is the tooltip.
    nonisolated public static func entry(
        _ label: String, id: String, enabled: Bool, unavailable: String? = nil
    ) -> ControlEntry {
        ControlEntry(id: id, enabled: enabled, reason: enabled ? nil : help(label, unavailable: unavailable))
    }

    /// The system control underneath: a segmented Picker over the drawn selection.
    var picker: some View {
        Picker(label, selection: Binding(get: { shown }, set: { onChange($0) })) {
            ForEach(tabs) { Text($0.title).tag($0.id) }
        }
    }

    public var body: some View {
        let enabled = isEnabled && unavailableHelp == nil
        let lit = (forcedHover ?? hovering) && enabled
        let help = Self.help(label, unavailable: unavailableHelp)
        VStack(spacing: 0) {
            picker
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(SuiteSize.compactControl)
                .tint(SuiteColor.selectedTint)
                .frame(maxWidth: .infinity)
                .frame(height: SuiteSize.chip)
                .padding(SuiteSpacing.xxs)
                .background(lit ? SuiteColor.rowHover : SuiteColor.row, in: Capsule())
                .contentShape(Capsule())
                .disabled(unavailableHelp != nil)
                .opacity(enabled ? 1 : SuiteColor.disabledOpacity)
                .onHover { hovering = $0 }
                .help(help)
                .suiteControl(id: id, enabled: enabled, reason: enabled ? nil : help)
                .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: lit)
                .padding(SuiteSpacing.s)
            Divider()
        }
        .onChange(of: selection) { _, new in
            TabsProbe.fade(reduceMotion: reduceMotion, probe: probe) { shown = new }
        }
    }
}

/// Where the tabs report their selection fades (a probe host sets it; nil
/// records nothing): a `fade-start`/`fade-end` mark pair on series `tabs`.
struct TabsProbe: Sendable {
    static let fadeSeries = "tabs"
    let record: @MainActor @Sendable (ProbeMark) -> Void

    /// Runs `change` under the state fade (none under Reduce Motion), marking its start and its end.
    @MainActor static func fade(reduceMotion: Bool, probe: TabsProbe?, _ change: () -> Void) {
        probe?.record(ProbeMark(name: "fade-start", series: fadeSeries, time: ProcessInfo.processInfo.systemUptime))
        // The completion runs exactly once: after the fade, or at once when nothing animates.
        withAnimation(SuiteMotion.state(reduceMotion: reduceMotion), change) {
            probe?.record(ProbeMark(name: "fade-end", series: fadeSeries, time: ProcessInfo.processInfo.systemUptime))
        }
    }
}

extension EnvironmentValues {
    /// Where the tabs report their fades; nil records nothing.
    var tabsProbe: TabsProbe? {
        get { self[TabsProbeKey.self] }
        set { self[TabsProbeKey.self] = newValue }
    }

    /// Draws the tabs as hovered (true) or not (false) whatever the pointer does; nil follows it. Snapshots set it.
    var tabsHover: Bool? {
        get { self[TabsHoverKey.self] }
        set { self[TabsHoverKey.self] = newValue }
    }
}

private struct TabsProbeKey: EnvironmentKey {
    static let defaultValue: TabsProbe? = nil
}

private struct TabsHoverKey: EnvironmentKey {
    static let defaultValue: Bool? = nil
}
