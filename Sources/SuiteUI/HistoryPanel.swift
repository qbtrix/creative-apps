// HistoryPanel.swift (autosave-history AH-3): the one History panel every app shows over the kernel's
// `HistoryListing` (packet docs/blueprints/suiteui/features/autosave-history.md). One row per state, "Open" (the
// listing's base) at 0, then each step, oldest first. The current state is selected (the selected tint, the
// headline font); the undone steps after it are secondary text and read "…, not applied"; the saved state carries a
// small dot. A click on a row jumps to it; Up and Down move the selection without jumping, stopping at "Open" and
// the last step, and Return jumps to the selected row. Every jump goes out once through `onJump`; the panel mutates
// nothing, and its selection returns to the listing's index whenever the listing changes. The selection and key rule
// is `HistoryPanelCursor`, a value tested without a window. Each row is a button (`suite.history.row.<n>`) whose
// style shows hover, press and selection (`HistoryRowLook`); rows are lazy in the panel's scroll view and their
// content is `.equatable()` on plain values (swiftui-rules 2, 5, 10); "No changes yet." shows under "Open" alone.
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
        Button {
            focused = true
            click(position)
        } label: {
            HistoryPanelRow(
                name: Self.name(at: position, in: listing), isCurrent: position == listing.index,
                isApplied: position <= listing.index, isSaved: listing.savedIndex == position)
                .equatable()
        }
        .buttonStyle(HistoryRowStyle(isSelected: position == cursor.position))
        // Tab stops on the panel, whose arrows and Return walk the rows, not on each row.
        .focusable(false)
        .accessibilityLabel(Self.label(at: position, in: listing))
        .accessibilityAddTraits(position == cursor.position ? .isSelected : [])
        .accessibilityIdentifier("suite.history.row.\(position)")
        .id(position)
    }
}

/// How a row draws its state: a press wins, then the selection, then the pointer. Hover is a `rowHover` fill with an
/// `outline` edge, never fill alone (docs/design.md, Surfaces); a press takes the field fill, as HoverButtonLevel's.
enum HistoryRowLook: Equatable, Sendable {
    case rest, hover, selected, pressed

    static func resolve(selected: Bool, hovering: Bool, pressed: Bool) -> Self {
        pressed ? .pressed : selected ? .selected : hovering ? .hover : .rest
    }

    var fill: Color {
        switch self {
        case .rest: Color.clear
        case .hover: SuiteColor.rowHover
        case .selected: SuiteColor.selectedTint
        case .pressed: SuiteColor.field
        }
    }

    var outlined: Bool { self == .hover }
}

/// A row's button look: HistoryRowLook's fill and edge under the whole row, the hover written on enter and exit only,
/// never per pointer sample (swiftui-rules 1).
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
            let look = HistoryRowLook.resolve(selected: isSelected, hovering: hovering, pressed: configuration.isPressed)
            configuration.label
                .contentShape(.rect)
                .background(look.fill, in: RoundedRectangle(cornerRadius: SuiteRadius.row))
                .overlay {
                    if look.outlined {
                        RoundedRectangle(cornerRadius: SuiteRadius.row)
                            .strokeBorder(SuiteColor.outline, lineWidth: 1)
                            .allowsHitTesting(false)
                    }
                }
                .onHover { hovering = $0 }
                .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: isSelected)
        }
    }
}

/// One state's row: plain values in, so SwiftUI skips it when they compare equal; its button style draws the state.
private struct HistoryPanelRow: View, Equatable {
    let name: String
    let isCurrent: Bool
    let isApplied: Bool
    let isSaved: Bool

    var body: some View {
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
}
