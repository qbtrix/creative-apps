// ChoiceChips.swift: the Studio editor's preset chips (Flare's easing
// presets): a PresetGrid in three columns, so the suite has one preset grid,
// with its arrow-key rule (SuitePresetNavigating unless a page passes one).
// Inside a ToolOptionsBar (`toolOptionsAxis` horizontal) the chips sit in one
// row, each SuiteSize.toolOptionsChip wide.
import SwiftUI

public struct ChoiceChips<ID: Hashable & Sendable>: View {
    private let options: [InspectorOption<ID>]
    private let selected: ID?
    private let navigation: any PresetNavigating
    private let onSelect: @MainActor (ID) -> Void
    @Environment(\.toolOptionsAxis) private var axis

    public init(
        options: [InspectorOption<ID>], selected: ID?, navigation: any PresetNavigating = SuitePresetNavigating(),
        onSelect: @escaping @MainActor (ID) -> Void
    ) {
        (self.options, self.selected, self.navigation, self.onSelect) = (options, selected, navigation, onSelect)
    }

    public var body: some View {
        if axis == .horizontal {
            PresetGrid(options: options, selected: selected, columns: options.count, navigation: navigation, onSelect: onSelect)
                .frame(width: CGFloat(options.count) * SuiteSize.toolOptionsChip)
        } else {
            PresetGrid(options: options, selected: selected, columns: 3, navigation: navigation, onSelect: onSelect)
        }
    }
}
