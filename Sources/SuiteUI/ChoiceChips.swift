// ChoiceChips.swift: the Studio editor's preset chips (Flare's easing
// presets): a PresetGrid in three columns, so the suite has one preset grid.
import SwiftUI

public struct ChoiceChips<ID: Hashable & Sendable>: View {
    private let grid: PresetGrid<ID>

    public init(options: [InspectorOption<ID>], selected: ID?, onSelect: @escaping @MainActor (ID) -> Void) {
        grid = PresetGrid(options: options, selected: selected, columns: 3, onSelect: onSelect)
    }

    public var body: some View { grid }
}
