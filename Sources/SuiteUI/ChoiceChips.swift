// ChoiceChips.swift: the Studio editor's preset chips, a three-column grid of
// small rounded buttons where one may be active. Rest is a raised grey with
// secondary text, hover the field grey with primary text, active the selected
// well with an accent border. `selected` may be nil (no preset matches, as
// after a handle drag). A chip is a real Button, so Tab reaches it and Space
// presses it. Owns presentation state only: which chip is hovered.
import SwiftUI

public struct ChoiceChips<ID: Hashable & Sendable>: View {
    private let options: [InspectorOption<ID>]
    private let selected: ID?
    private let onSelect: @MainActor (ID) -> Void
    @State private var hovered: ID?

    public init(options: [InspectorOption<ID>], selected: ID?, onSelect: @escaping @MainActor (ID) -> Void) {
        self.options = options
        self.selected = selected
        self.onSelect = onSelect
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: SuiteSpacing.xs), count: 3), spacing: SuiteSpacing.xs) {
            ForEach(options) { option in
                let active = option.id == selected
                let lit = active || option.id == hovered
                Button(option.title) { onSelect(option.id) }
                    .buttonStyle(.plain)
                    .font(SuiteFont.caption.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(lit ? Color.primary : SuiteColor.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: SuiteSize.preset, maxHeight: SuiteSize.preset)
                    .background(
                        active ? SuiteColor.selectedWell : option.id == hovered ? SuiteColor.field : SuiteColor.panelRaised,
                        in: RoundedRectangle(cornerRadius: SuiteRadius.row))
                    .overlay {
                        if active { RoundedRectangle(cornerRadius: SuiteRadius.row).strokeBorder(SuiteColor.accent, lineWidth: 1) }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: SuiteRadius.row))
                    .onHover { hovered = $0 ? option.id : (hovered == option.id ? nil : hovered) }
                    .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
    }
}
