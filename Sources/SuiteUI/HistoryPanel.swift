// HistoryPanel.swift (autosave-history AH-3): the one History panel every app shows over the kernel's
// `HistoryListing` (packet docs/blueprints/suiteui/features/autosave-history.md). One row per state, "Open" (the
// listing's base) at 0, then each step, oldest first. The current state is selected (the selected tint, the
// headline font); the undone steps after it are secondary text and read "…, not applied"; the saved state carries a
// small dot. Each row is a button whose surface shows hover, press and selection (`HistoryRowLook`, a value tested
// without a window). A click on a row jumps to it; Up and Down move the selection without jumping, stopping at "Open"
// and the last step, and Return jumps to the selected row. Every jump goes out once through `onJump`; the panel mutates
// nothing, and its selection returns to the listing's index whenever the listing changes. The selection and key rule
// is `HistoryPanelCursor`, a value tested without a window. Rows are `suite.history.row.<n>`, lazy in the panel's
// scroll view, `.equatable()` on plain values (swiftui-rules 2, 5); "No changes yet." shows under "Open" alone.
import SuiteKernel
import SwiftUI

/// The panel's keyboard selection over states 0...`last`: arrows move it and stop at the ends; Return names the
/// state to jump to.
struct HistoryPanelCursor: Equatable, Sendable {
    enum Key: Equatable, Sendable { case up, down, enter }

    /// The last state, the step count; 0 when there are no steps.
    let last: Int
    /// The selected state.
    private(set) var position: Int

    /// Starts on the listing's current state, clamped into 0...steps.count.
    init(_ listing: HistoryListing) {
        last = listing.steps.count
        position = min(max(listing.index, 0), listing.steps.count)
    }

    /// Moves for an arrow and returns nil; Return returns the selected state, to jump to.
    mutating func press(_ key: Key) -> Int? {
        switch key {
        case .up: position = max(position - 1, 0)
        case .down: position = min(position + 1, last)
        case .enter: return position
        }
        return nil
    }

    /// The cursor key a pressed key stands for; nil for any other key.
    static func key(_ key: KeyEquivalent) -> Key? {
        switch key {
        case .upArrow: .up
        case .downArrow: .down
        case .return: .enter
        default: nil
        }
    }
}

public struct HistoryPanel: View {
    private let listing: HistoryListing
    /// Called with the number of steps to apply, 0 for the base.
    private let onJump: @MainActor (Int) -> Void
    @State private var cursor: HistoryPanelCursor
    @FocusState private var focused: Bool

    public init(listing: HistoryListing, onJump: @escaping @MainActor (Int) -> Void) {
        self.listing = listing
        self.onJump = onJump
        _cursor = State(initialValue: HistoryPanelCursor(listing))
    }

    /// A click on row `position`: one jump to it; a position outside the rows does nothing.
    func click(_ position: Int) {
        guard (0...listing.steps.count).contains(position) else { return }
        onJump(position)
    }

    /// A key on the panel: an arrow moves `cursor`, Return jumps once to the state it selects.
    func press(_ key: HistoryPanelCursor.Key, on cursor: inout HistoryPanelCursor) {
        if let position = cursor.press(key) { click(position) }
    }

    /// The base at 0, else step `position` (1-based).
    nonisolated static func name(at position: Int, in listing: HistoryListing) -> String {
        position > 0 && listing.steps.indices.contains(position - 1) ? listing.steps[position - 1] : listing.base
    }

    /// What VoiceOver reads for row `position`: "Step 6 of 11, Move, applied", the base as "Open, applied", a saved
    /// state with ", saved" before whether it is applied, and every row past the index ending "not applied".
    nonisolated static func label(at position: Int, in listing: HistoryListing) -> String {
        let name = name(at: position, in: listing)
        let title = position == 0 ? name : "Step \(position) of \(listing.steps.count), \(name)"
        let saved = listing.savedIndex == position ? ", saved" : ""
        return title + saved + (position <= listing.index ? ", applied" : ", not applied")
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(0...listing.steps.count, id: \.self) { position in
                        row(position)
                    }
                    if listing.steps.isEmpty {
                        Text("No changes yet.")
                            .font(SuiteFont.caption)
                            .foregroundStyle(SuiteColor.secondaryText)
                            .padding(.horizontal, SuiteSpacing.s)
                            .padding(.vertical, SuiteSpacing.xs)
                    }
                }
                .padding(.vertical, SuiteSpacing.xs)
            }
            .onChange(of: cursor.position) { _, position in proxy.scrollTo(position) }
        }
        // Full keyboard access: Tab reaches the panel, a click gives it focus, then the arrows and Return act here.
        .focusable()
        .focused($focused)
        .onKeyPress(keys: [.upArrow, .downArrow, .return]) { key in
            guard let cursorKey = HistoryPanelCursor.key(key.key) else { return .ignored }
            press(cursorKey, on: &cursor)
            return .handled
        }
        .onChange(of: listing) { _, listing in cursor = HistoryPanelCursor(listing) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.history")
    }

    private func row(_ position: Int) -> some View {
        HistoryPanelRow(
            name: Self.name(at: position, in: listing), label: Self.label(at: position, in: listing),
            isSelected: position == cursor.position, isCurrent: position == listing.index,
            isApplied: position <= listing.index, isSaved: listing.savedIndex == position
        ) {
            focused = true
            click(position)
        }
        .equatable()
        .accessibilityIdentifier("suite.history.row.\(position)")
        .id(position)
    }
}

/// What a row shows under the pointer: a press shows at once, even on the selected row; the selected row keeps its
/// tint under the pointer; hover is only for an idle row (swiftui-rules 10).
enum HistoryRowLook: Hashable, Sendable {
    case plain, hovered, pressed, selected

    static func resolve(selected: Bool, hovering: Bool, pressed: Bool) -> HistoryRowLook {
        if pressed { return .pressed }
        if selected { return .selected }
        return hovering ? .hovered : .plain
    }

    var fill: Color {
        switch self {
        case .plain: Color.clear
        case .hovered: SuiteColor.rowHover
        case .pressed: SuiteColor.field
        case .selected: SuiteColor.selectedTint
        }
    }

    /// Hover and press add an outline, so neither reads by fill alone (docs/design.md, Surfaces).
    var outlined: Bool { self == .hovered || self == .pressed }
}

/// A row's button surface: the fill and outline of its `HistoryRowLook`. Owns presentation state only: hover.
private struct HistoryRowStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        HistoryRowBody(configuration: configuration, isSelected: isSelected)
    }

    private struct HistoryRowBody: View {
        let configuration: ButtonStyleConfiguration
        let isSelected: Bool
        @State private var hovering = false
        @Environment(\.suiteReduceMotion) private var reduceMotion

        var body: some View {
            let look = HistoryRowLook.resolve(
                selected: isSelected, hovering: hovering, pressed: configuration.isPressed)
            let shape = RoundedRectangle(cornerRadius: SuiteRadius.row)
            configuration.label
                .background(look.fill, in: shape)
                .overlay {
                    if look.outlined { shape.strokeBorder(SuiteColor.outline, lineWidth: 1).allowsHitTesting(false) }
                }
                .contentShape(shape)
                // Written on enter and exit only, never per pointer sample (swiftui-rules 1).
                .onHover { hovering = $0 }
                .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: isSelected)
        }
    }
}

/// One state's row, a button on `HistoryRowStyle`: plain values in, so SwiftUI skips it when they compare equal (the
/// press action is left out of `==`, swiftui-rules 2). The panel takes keyboard focus, not each row: Tab reaches the
/// list once, then the arrows move in it.
private struct HistoryPanelRow: View, Equatable {
    let name: String
    let label: String
    let isSelected: Bool
    let isCurrent: Bool
    let isApplied: Bool
    let isSaved: Bool
    let onPress: @MainActor () -> Void

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.name == rhs.name && lhs.label == rhs.label && lhs.isSelected == rhs.isSelected
            && lhs.isCurrent == rhs.isCurrent && lhs.isApplied == rhs.isApplied && lhs.isSaved == rhs.isSaved
    }

    var body: some View {
        Button(action: onPress) {
            HStack(spacing: SuiteSpacing.xs) {
                Text(name)
                    .font(isCurrent ? SuiteFont.headline : SuiteFont.body)
                    .foregroundStyle(isApplied ? SuiteColor.textPrimary : SuiteColor.secondaryText)
                    .lineLimit(1)
                Spacer(minLength: SuiteSpacing.s)
                if isSaved {
                    Image(systemName: "circle.fill")
                        .resizable()
                        .frame(width: SuiteSize.statusDot, height: SuiteSize.statusDot)
                        .foregroundStyle(SuiteColor.textSecondary)
                        .help("Saved")
                }
            }
            .frame(minHeight: SuiteSize.studioRow)
            .padding(.horizontal, SuiteSpacing.s)
        }
        .buttonStyle(HistoryRowStyle(isSelected: isSelected))
        .focusable(false)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
