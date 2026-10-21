// SuiteHistoryPanelSnapshots.swift (autosave-history AH-4): the History panel in Light and Dark. The gallery's
// `history-panel` page as it opens, "Open" and eleven steps, the eighth current and selected, the three after it
// dimmed: suiteui-history-panel-{light,dark}.png. The same listing saved at step 3, its row carrying the saved dot:
// suiteui-history-panel-saved-{light,dark}.png. "Open" alone over "No changes yet.":
// suiteui-history-panel-empty-{light,dark}.png. The labels the rows read are checked beside each picture, since the
// picture can't say which rows are undone. macOS only.
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteHistoryPanelSnapshots {
    /// The panel at the gallery page's width and padding, over a listing the test picks.
    private func page(_ listing: HistoryListing) -> some View {
        HistoryPanel(listing: listing, onJump: { _ in })
            .frame(maxWidth: SuiteSize.editorPanelWidth, maxHeight: .infinity)
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @Test func galleryPageCurrentAndUndone() throws {
        let listing = GalleryHistoryPanel.listing
        #expect(listing.steps.count == 11 && listing.index == 8)
        #expect(HistoryPanel.label(at: 8, in: listing) == "Step 8 of 11, Levels, applied")
        #expect(HistoryPanel.label(at: 9, in: listing) == "Step 9 of 11, Brush, not applied")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GalleryHistoryPanelPage(), name: "suiteui-history-panel-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func savedStepHasItsDot() throws {
        var listing = GalleryHistoryPanel.listing
        listing.savedIndex = 3
        #expect(HistoryPanel.label(at: 3, in: listing) == "Step 3 of 11, Fill, saved, applied")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(page(listing), name: "suiteui-history-panel-saved-\(scheme.name)", scheme: scheme)
        }
    }

    /// Identical step names stay apart on screen: each step row shows its position, the base shows none, and the
    /// saved state's dot carries a visible "Saved" caption (finding #3947).
    @Test func stepRowsShowTheirPosition() {
        var listing = HistoryListing(base: "Open", steps: Array(repeating: "Add Rectangle", count: 3), index: 3)
        listing.savedIndex = 2
        #expect(HistoryPanel.visibleText(at: 0, in: listing) == ["Open"])
        #expect(HistoryPanel.visibleText(at: 1, in: listing) == ["1", "Add Rectangle"])
        #expect(HistoryPanel.visibleText(at: 2, in: listing) == ["2", "Add Rectangle", "Saved"])
        #expect(HistoryPanel.visibleText(at: 3, in: listing) == ["3", "Add Rectangle"])
        #expect(HistoryPanel.position(at: 4, in: listing) == nil)
    }

    @Test func emptyListsOpenAlone() throws {
        let listing = HistoryListing(base: "Open", steps: [], index: 0)
        #expect(HistoryPanel.label(at: 0, in: listing) == "Open, applied")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(page(listing), name: "suiteui-history-panel-empty-\(scheme.name)", scheme: scheme)
        }
    }
}
