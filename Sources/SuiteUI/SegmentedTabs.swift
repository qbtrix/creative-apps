// SegmentedTabs.swift: the tab switch at the top of an editor's right panel
// (Adjust | Layers), a system segmented Picker filling the panel's width
// (`buttonSizing(.flexible)`; a frame alone leaves it label-wide) on a
// flat band that ends in a hairline. It draws as a capsule (docs/design.md,
// Tabs): a `row` capsule with 2 pt padding round `chip`-tall segments, the
// selected one on the `stateSelected` tint, the capsule on `rowHover` under
// the pointer and at 40% while disabled. It stays a `Picker` underneath, so
// the system draws the segments, Tab reaches it and VoiceOver reads it as one.
// A click on a segment also puts focus in it, so ← and → then step to the
// previous or next tab (`step`) with keyboard navigation off too, and each
// segment carries its option's identifier, or `<id>.<option id>`, and is
// listed in `suite.controls` under it (`segmentEntries`), the picked one
// `selected: true` and the rest `false`.
// A selection change fades over 0.14 s (at once under `suiteReduceMotion`)
// and reports a `fade-start`/`fade-end` pair on series `tabs` (QB-S9;
// TabsProbe, which a probe host sets). Given an `id` it lists itself in
// `suite.controls`, its reason while unavailable being its tooltip
// (`entry`). Value in, `onChange` out: the host keeps which tab is showing
// as its own presentation state. Owns presentation state only: hover, focus
// and the selection drawn while it fades.
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
    /// Whether focus is in the switch, so ← and → reach it.
    @FocusState private var focused: Bool
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

    /// The tab `offset` places from `current` (-1 for ←, 1 for →), or nil past either end.
    nonisolated public static func step(_ tabs: [ID], from current: ID, by offset: Int) -> ID? {
        guard let index = tabs.firstIndex(of: current) else { return nil }
        let next = index + offset
        return tabs.indices.contains(next) ? tabs[next] : nil
    }

    /// The accessibility identifier of `option`'s segment: its own, else `<id>.<option id>`; nil without an `id`.
    nonisolated static func segmentID(_ option: InspectorOption<ID>, in id: String?) -> String? {
        option.identifier ?? id.map { "\($0).\(String(describing: option.id))" }
    }

    /// The `suite.controls` entries of the identified segments, which share the switch's state and reason.
    nonisolated static func segmentEntries(
        _ tabs: [InspectorOption<ID>], in id: String?, enabled: Bool, reason: String?, selection: ID? = nil
    ) -> [ControlEntry] {
        tabs.compactMap { option in
            segmentID(option, in: id).map {
                ControlEntry(id: $0, enabled: enabled, reason: enabled ? nil : reason)
                    .selecting(selection.map { picked in option.id == picked })
            }
        }
    }

    /// The system control underneath: a segmented Picker over the drawn selection.
    var picker: some View {
        Picker(label, selection: Binding(get: { shown }, set: { focused = true; onChange($0) })) {
            ForEach(tabs) { option in
                Text(option.title).tag(option.id).accessibilityIdentifier(Self.segmentID(option, in: id) ?? "")
            }
        }
    }

    /// Steps to the neighbouring tab on ← or →; other keys pass on.
    private func stepKey(_ offset: Int) -> KeyPress.Result {
        guard let next = Self.step(tabs.map(\.id), from: shown, by: offset) else { return .ignored }
        onChange(next)
        return .handled
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
                // A frame alone leaves the system control label-wide in the middle of the capsule.
                .buttonSizing(.flexible)
                .buttonBorderShape(.capsule)
                .frame(maxWidth: .infinity)
                .frame(height: SuiteSize.chip)
                .padding(SuiteSpacing.xxs)
                .background(lit ? SuiteColor.rowHover : SuiteColor.row, in: Capsule())
                .contentShape(Capsule())
                .disabled(unavailableHelp != nil)
                // Focusable on a click, not only under keyboard navigation (focusable(_:interactions:)).
                .focusable(enabled)
                .focused($focused)
                .focusEffectDisabled()
                .onKeyPress(.leftArrow) { stepKey(-1) }
                .onKeyPress(.rightArrow) { stepKey(1) }
                .opacity(enabled ? 1 : SuiteColor.disabledOpacity)
                .onHover { hovering = $0 }
                .help(help)
                .suiteControl(id: id, enabled: enabled, reason: enabled ? nil : help)
                .background {
                    // The segments keep the identifiers the picker set; these only list them.
                    let entries = Self.segmentEntries(tabs, in: id, enabled: enabled, reason: help, selection: selection)
                    ForEach(entries, id: \.id) { entry in
                        Color.clear.suiteControl(entry: entry, identifies: false)
                    }
                }
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
    /// How long `SuiteMotion.state` runs: 0.14 s.
    static let fadeLength: TimeInterval = 0.14
    let record: @MainActor @Sendable (ProbeMark) -> Void

    /// Runs `change` under the state fade (none under Reduce Motion), marking its start and its end.
    @MainActor static func fade(reduceMotion: Bool, probe: TabsProbe?, _ change: () -> Void) {
        probe?.record(ProbeMark(name: "fade-start", series: fadeSeries, time: ProcessInfo.processInfo.systemUptime))
        withAnimation(SuiteMotion.state(reduceMotion: reduceMotion), change)
        // The drawn selection is a system segmented control, so the change creates no SwiftUI animation, and a
        // completion run from onChange waited for the next transaction (start, start, end on scoped run
        // 39133362138, #2805). The pair closes on its own instead: at once under Reduce Motion, else after the
        // fade, on a main-run-loop timer. A main-actor Task never ran while the caller spun the run loop holding
        // the main actor (start, start on scoped run 39137893783).
        guard let probe else { return }
        if reduceMotion {
            probe.record(ProbeMark(name: "fade-end", series: fadeSeries, time: ProcessInfo.processInfo.systemUptime))
            return
        }
        Timer.scheduledTimer(withTimeInterval: fadeLength, repeats: false) { _ in
            MainActor.assumeIsolated {
                probe.record(ProbeMark(name: "fade-end", series: fadeSeries, time: ProcessInfo.processInfo.systemUptime))
            }
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
