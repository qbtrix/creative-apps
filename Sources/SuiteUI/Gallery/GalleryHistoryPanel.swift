// GalleryHistoryPanel.swift: the gallery's `history-panel` page (autosave-history AH-2; AH-8 runs it on a kernel
// `History`). It shows HistoryPanel over a local listing: "Open" and eleven steps, eight applied, so the three after
// the current one read as undone. A jump the panel asks for moves the page's own index and writes one line,
// `history.jump {"index": <n>}`, to the `suite.gallery.log` element the journey reads. The page is listed in
// `GalleryLists.pages`, beside the other list pages.
import SuiteKernel
import SwiftUI

enum GalleryHistoryPanel {
    static let name = "history-panel"

    /// "Open" and eleven steps, the eighth current; the sixth is "Move" (VoiceOver's "Step 6 of 11, Move").
    static let listing = HistoryListing(
        base: "Open",
        steps: ["Brush", "Brush", "Fill", "Erase", "Brush", "Move", "Transform", "Levels", "Brush", "Crop", "Rename"],
        index: 8)

    /// The page's log line for a jump to `index` applied steps.
    static func line(_ index: Int) -> String { "history.jump {\"index\": \(index)}" }
}

/// The `history-panel` page: HistoryPanel on the page's own listing, and the log under it.
struct GalleryHistoryPanelPage: View {
    @State private var listing = GalleryHistoryPanel.listing
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HistoryPanel(listing: listing, onJump: jump)
                .frame(maxWidth: SuiteSize.editorPanelWidth, maxHeight: .infinity)
            GalleryListLog(lines: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func jump(_ index: Int) {
        guard (0...listing.steps.count).contains(index) else { return }
        listing.index = index
        log.append(GalleryHistoryPanel.line(index))
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}
