// PresetGrid.swift: a grid of preset buttons where one may be on (two equal
// columns by default, 4 pt apart), drawn as Flare's easing presets
// (SuiteChipStyle). An option's `identifier` lands on its own button.
// `selected` may be nil (no preset matches, as after a handle drag). Arrow
// keys move focus within the grid through a PresetNavigating rule (UC4; the
// live SuitePresetNavigating stops at the edges, a gallery page may pass
// FakePresetNavigating), and Space presses the focused preset. Each press
// reports a `press` sample to the chip probe (ChipProbe). Owns presentation
// state only: which preset has focus.
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

    public var body: some View {
        // The 28 pt hit rows overlap the 4 pt between their 24 pt drawings.
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: SuiteSpacing.xs), count: columns),
            spacing: SuiteSpacing.xs - (SuiteSize.presetHit - SuiteSize.preset)
        ) {
            ForEach(options) { option in
                Button(option.title) { ChipProbe.press(probe) { onSelect(option.id) } }
                    .buttonStyle(SuiteChipStyle(kind: .preset, isOn: option.id == selected))
                    .focused($focused, equals: option.id)
                    .accessibilityAddTraits(option.id == selected ? .isSelected : [])
                    .accessibilityIdentifier(option.identifier ?? "")
            }
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow, .upArrow, .downArrow]) { press in
            guard let current = options.firstIndex(where: { $0.id == focused }),
                let arrow = Self.arrow(press.key),
                let next = navigation.neighbor(of: current, arrow, count: options.count, columns: columns),
                options.indices.contains(next)
            else { return .ignored }
            focused = options[next].id
            return .handled
        }
    }
}
