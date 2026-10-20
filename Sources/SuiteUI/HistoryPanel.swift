// HistoryPanel.swift (autosave-history AH-2 placeholder, AH-3 view): the one History panel every app shows over
// the kernel's `HistoryListing` (packet docs/blueprints/suiteui/features/autosave-history.md). One row per state,
// "Open" (the listing's base) then each step, oldest first; the current state in the headline font and the undone
// steps after it in secondary text; "No changes yet." under "Open" when there are no steps. The placeholder draws
// the rows only: none is a control yet, so nothing on it looks clickable. AH-3 makes the rows select and jump
// through `onJump` (a click, or the arrows and Return), with the saved dot and `suite.history.row.<n>` ids.
import SuiteKernel
import SwiftUI

public struct HistoryPanel: View {
    private let listing: HistoryListing
    /// Called with the number of steps to apply, 0 for the base; AH-3 wires the rows to it.
    private let onJump: @MainActor (Int) -> Void

    public init(listing: HistoryListing, onJump: @escaping @MainActor (Int) -> Void) {
        self.listing = listing
        self.onJump = onJump
    }

    public var body: some View {
        List {
            ForEach(0..<(listing.steps.count + 1), id: \.self) { position in
                HistoryPanelRow(name: name(at: position), isCurrent: position == listing.index,
                                isApplied: position <= listing.index)
            }
            if listing.steps.isEmpty {
                Text("No changes yet.")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.history")
    }

    /// The base at 0, else the step `position` (1-based).
    private func name(at position: Int) -> String {
        position > 0 && listing.steps.indices.contains(position - 1) ? listing.steps[position - 1] : listing.base
    }
}

/// One state's row: its name, the headline font when current, secondary text when undone.
private struct HistoryPanelRow: View {
    let name: String
    let isCurrent: Bool
    let isApplied: Bool

    var body: some View {
        Text(name)
            .font(isCurrent ? SuiteFont.headline : SuiteFont.body)
            .foregroundStyle(isApplied ? SuiteColor.textPrimary : SuiteColor.secondaryText)
            .lineLimit(1)
    }
}
