// LibraryStatusBar.swift: the row under the Library window's content while the
// catalog runs on the fakes (`services.isPreview`): a ViewerStatusBar whose
// zoom and size pills show the loupe's zoom (100% in the grid) and the photo
// count, then a "Preview data" warning pill whose tooltip and accessibility
// hint say it is built-in sample data.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryStatusBar: View {
    let model: LibraryCatalog

    /// What the "Preview data" pill means, as its tooltip and accessibility hint.
    static let previewHelp = "This window shows built-in sample data, not photos on disk."

    var body: some View {
        ViewerStatusBar(zoom: 1, size: Self.countText(model.items.count)) {
            if model.services.isPreview {
                Text("Preview data").accessibilityIdentifier("library.status.preview").statusPill(.warning)
                    .help(Self.previewHelp)
                    .accessibilityHint(Self.previewHelp)
            }
        }
    }

    /// "1 photo", "26 photos".
    static func countText(_ count: Int) -> String {
        count == 1 ? "1 photo" : "\(count) photos"
    }
}
