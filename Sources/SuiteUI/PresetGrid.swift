// PresetGrid.swift: a grid of preset buttons where one may be on (two equal
// columns by default, 4 pt apart), drawn as Flare's easing presets
// (SuiteChipStyle). An option's `identifier` lands on its own button.
// `selected` may be nil (no preset matches, as after a handle drag). Arrow
// keys move focus within the grid (`neighbor`), Space presses the focused
// preset. Owns presentation state only: which preset has focus.
import SwiftUI

public struct PresetGrid<ID: Hashable & Sendable>: View {
    private let options: [InspectorOption<ID>]
    private let selected: ID?
    private let columns: Int
    private let onSelect: @MainActor (ID) -> Void
    @FocusState private var focused: ID?

    public init(
        options: [InspectorOption<ID>], selected: ID?, columns: Int = 2, onSelect: @escaping @MainActor (ID) -> Void
    ) {
        self.options = options
        self.selected = selected
        self.columns = max(columns, 1)
        self.onSelect = onSelect
    }

    /// The index an arrow key moves focus to from `index` in a grid of `count`
    /// items laid out in `columns`, or nil at an edge (focus stays).
    public static func neighbor(of index: Int, _ key: KeyEquivalent, count: Int, columns: Int) -> Int? {
        let next: Int
        switch key {
        case .leftArrow: next = index % columns == 0 ? -1 : index - 1
        case .rightArrow: next = (index + 1) % columns == 0 ? count : index + 1
        case .upArrow: next = index - columns
        case .downArrow: next = index + columns
        default: return nil
        }
        return (0..<count).contains(next) ? next : nil
    }

    public var body: some View {
        // The 28 pt hit rows overlap the 4 pt between their 24 pt drawings.
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: SuiteSpacing.xs), count: columns),
            spacing: SuiteSpacing.xs - (SuiteSize.presetHit - SuiteSize.preset)
        ) {
            ForEach(options) { option in
                Button(option.title) { onSelect(option.id) }
                    .buttonStyle(SuiteChipStyle(kind: .preset, isOn: option.id == selected))
                    .focused($focused, equals: option.id)
                    .accessibilityAddTraits(option.id == selected ? .isSelected : [])
                    .accessibilityIdentifier(option.identifier ?? "")
            }
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            guard let current = options.firstIndex(where: { $0.id == focused }),
                let next = Self.neighbor(of: current, press.key, count: options.count, columns: columns)
            else { return .ignored }
            focused = options[next].id
            return .handled
        }
    }
}
