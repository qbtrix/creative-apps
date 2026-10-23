// PresetGrid.swift: a grid of preset buttons where one may be on (two equal
// columns by default, 4 pt apart), drawn as Flare's easing presets
// (SuiteChipStyle). An option's `identifier` lands on its own button.
// `selected` may be nil (no preset matches, as after a handle drag). Arrow
// keys move focus within the grid through a PresetNavigating rule (UC4; the
// live SuitePresetNavigating stops at the edges, a gallery page may pass
// FakePresetNavigating), and Space presses the focused preset. A click
// focuses the preset it presses, so arrows then start there, not at whatever
// control had focus before (#2927). Each press reports a `press` sample to the
// chip probe (ChipProbe). Owns presentation state only: which preset has focus.
import SwiftUI

/// The live preset-grid rule: an arrow moves one cell and stops at the grid's edges (no wrap).
public struct SuitePresetNavigating: PresetNavigating {
    public init() {}

    public func neighbor(of index: Int, _ arrow: GridArrow, count: Int, columns: Int) -> Int? {
        guard columns > 0, (0..<count).contains(index) else { return nil }
        let next: Int
        switch arrow {
        case .left: next = index % columns == 0 ? -1 : index - 1
        case .right: next = (index + 1) % columns == 0 ? count : index + 1
        case .up: next = index - columns
        case .down: next = index + columns
        }
        return (0..<count).contains(next) ? next : nil
    }
}

public struct PresetGrid<ID: Hashable & Sendable>: View {
    private let options: [InspectorOption<ID>]
    private let selected: ID?
    private let columns: Int
    private let navigation: any PresetNavigating
    private let onSelect: @MainActor (ID) -> Void
    @FocusState private var focused: ID?
    @Environment(\.chipProbe) private var probe

    public init(
        options: [InspectorOption<ID>], selected: ID?, columns: Int = 2,
        navigation: any PresetNavigating = SuitePresetNavigating(), onSelect: @escaping @MainActor (ID) -> Void
    ) {
        self.options = options
        self.selected = selected
        self.columns = max(columns, 1)
        self.navigation = navigation
        self.onSelect = onSelect
    }

    /// The grid arrow an arrow key stands for; nil for any other key.
    public static func arrow(_ key: KeyEquivalent) -> GridArrow? {
        switch key {
        case .leftArrow: .left
        case .rightArrow: .right
        case .upArrow: .up
        case .downArrow: .down
        default: nil
        }
    }

    /// The preset an arrow key moves focus to from `focused`; nil when nothing in the grid has focus or the arrow
    /// leaves the grid, so the key passes on.
    public nonisolated static func target(
        of arrow: GridArrow, from focused: ID?, in options: [InspectorOption<ID>], columns: Int,
        navigation: any PresetNavigating
    ) -> ID? {
        guard let current = options.firstIndex(where: { $0.id == focused }),
            let next = navigation.neighbor(of: current, arrow, count: options.count, columns: columns),
            options.indices.contains(next)
        else { return nil }
        return options[next].id
    }

    /// Presses `id`: it takes focus, then the grid reports the choice.
    private func press(_ id: ID) {
        focused = id
        ChipProbe.press(probe) { onSelect(id) }
    }

    public var body: some View {
        // The 28 pt hit rows overlap the 4 pt between their 24 pt drawings.
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: SuiteSpacing.xs), count: columns),
            spacing: SuiteSpacing.xs - (SuiteSize.presetHit - SuiteSize.preset)
        ) {
            ForEach(options) { option in
                Button(option.title) { press(option.id) }
                    .buttonStyle(SuiteChipStyle(kind: .preset, isOn: option.id == selected))
                    // Focusable on a click, not only under keyboard navigation (focusable(_:interactions:)).
                    .focusable()
                    .focused($focused, equals: option.id)
                    .accessibilityAddTraits(option.id == selected ? .isSelected : [])
                    .accessibilityIdentifier(option.identifier ?? "")
            }
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { key in
            guard let arrow = Self.arrow(key.key),
                let next = Self.target(of: arrow, from: focused, in: options, columns: columns, navigation: navigation)
            else { return .ignored }
            focused = next
            return .handled
        }
        // A focusable wrapper may hold focus instead of the system button, so Space presses the focused preset here.
        .onKeyPress(.space) {
            guard let id = focused else { return .ignored }
            press(id)
            return .handled
        }
    }
}
