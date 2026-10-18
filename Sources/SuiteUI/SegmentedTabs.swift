// SegmentedTabs.swift: the tab switch at the top of an editor's right panel
// (Adjust | Layers). It is the system segmented Picker, filling the panel's
// width, set in a `row` capsule with 2 pt padding on a flat band that ends in
// a hairline (docs/design.md, Tabs). Hover lights the capsule with `rowHover`
// and an outline; hover and a tab switch fade over SuiteMotion.state, at once
// under `suiteReduceMotion`, each reporting `fade-start` and `fade-end`
// (series `tabs`) to the probe host's fade mark. A switch that can't act yet
// is disabled with its reason as the tooltip, and registers in
// `suite.controls` when it has an identifier. Value in, `onChange` out: the
// host keeps which tab is showing as its own presentation state.
import SwiftUI

public struct SegmentedTabs<ID: Hashable & Sendable>: View {
    private let label: String
    private let tabs: [InspectorOption<ID>]
    private let selection: ID
    private let identifier: String?
    private let unavailableHelp: String?
    private let onChange: @MainActor (ID) -> Void
    /// Draws the hovered look without a pointer, for snapshots.
    var hoverPreview = false
    @State private var hovering = false
    @Environment(\.suiteReduceMotion) private var reduceMotion
    @Environment(\.timelineFadeMark) private var fadeMark

    /// `label` names the switch for VoiceOver; it is not drawn. With
    /// `unavailableHelp` the switch is disabled and that text is its tooltip;
    /// `identifier` lists it in `suite.controls`.
    public init(
        _ label: String, tabs: [InspectorOption<ID>], selection: ID, identifier: String? = nil,
        unavailableHelp: String? = nil, onChange: @escaping @MainActor (ID) -> Void
    ) {
        self.label = label
        self.tabs = tabs
        self.selection = selection
        self.identifier = identifier
        self.unavailableHelp = unavailableHelp
        self.onChange = onChange
    }

    /// The switch's `suite.controls` entry: disabled with its tooltip as the
    /// reason while unavailable; nil without an identifier.
    public var controlEntry: ControlEntry? {
        identifier.map { ControlEntry(id: $0, enabled: unavailableHelp == nil, reason: unavailableHelp) }
    }

    public var body: some View {
        let lit = (hovering || hoverPreview) && unavailableHelp == nil
        let capsule = Capsule()
        VStack(spacing: 0) {
            Picker(label, selection: Binding(get: { selection }, set: { tab in fade { onChange(tab) } })) {
                ForEach(tabs) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(SuiteSize.compactControl)
            .tint(SuiteColor.selectedTint)
            .frame(maxWidth: .infinity)
            .padding(SuiteSpacing.xxs)
            .background { capsule.fill(lit ? SuiteColor.rowHover : SuiteColor.row) }
            .overlay { if lit { capsule.strokeBorder(SuiteColor.outline, lineWidth: 1).allowsHitTesting(false) } }
            .contentShape(capsule)
            .onHover { over in fade { hovering = over } }
            .disabled(unavailableHelp != nil)
            // After .disabled, so the tooltip still shows on a disabled switch.
            .help(unavailableHelp ?? "")
            .suiteControl(id: identifier, enabled: unavailableHelp == nil, reason: unavailableHelp)
            .padding(SuiteSpacing.s)
            Divider()
        }
    }

    /// The hovered look, as a pointer over the switch would draw it.
    func showingHover() -> Self {
        var copy = self
        copy.hoverPreview = true
        return copy
    }

    /// Runs `change` under the state fade, marking its start and end.
    private func fade(_ change: () -> Void) {
        let mark = fadeMark
        mark?.record(ProbeMark(name: "fade-start", series: "tabs", time: ProcessInfo.processInfo.systemUptime))
        withAnimation(SuiteMotion.state(reduceMotion: reduceMotion)) {
            change()
        } completion: {
            mark?.record(ProbeMark(name: "fade-end", series: "tabs", time: ProcessInfo.processInfo.systemUptime))
        }
    }
}
