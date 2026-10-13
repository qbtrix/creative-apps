// SegmentedTabs.swift: the tab switch at the top of an editor's right panel
// (Adjust | Layers), a system segmented Picker filling the panel's width on a
// flat band that ends in a hairline. Value in, `onChange` out: the host keeps
// which tab is showing as its own presentation state.
import SwiftUI

public struct SegmentedTabs<ID: Hashable & Sendable>: View {
    private let label: String
    private let tabs: [InspectorOption<ID>]
    private let selection: ID
    private let onChange: @MainActor (ID) -> Void

    /// `label` names the switch for VoiceOver; it is not drawn.
    public init(
        _ label: String, tabs: [InspectorOption<ID>], selection: ID, onChange: @escaping @MainActor (ID) -> Void
    ) {
        self.label = label
        self.tabs = tabs
        self.selection = selection
        self.onChange = onChange
    }

    public var body: some View {
        VStack(spacing: 0) {
            Picker(label, selection: Binding(get: { selection }, set: { onChange($0) })) {
                ForEach(tabs) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(SuiteSize.compactControl)
            .frame(maxWidth: .infinity)
            .padding(SuiteSpacing.s)
            Divider()
        }
    }
}
