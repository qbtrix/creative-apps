// LibraryStatusBar.swift: the row under the Library window's content in the
// loupe and, on preview data (`services.isPreview`), in the grid too
// (`showsStatusBar`). A ViewerStatusBar whose zoom pill shows the scale the
// loupe draws at (its zoom against the fit the loupe measured; 100% in the
// grid) and whose size pill shows the loupe photo's pixel size, or the photo
// count in the grid. On preview data a "Preview data" warning pill follows,
// whose tooltip and accessibility hint say it is built-in sample data.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryStatusBar: View {
    let model: LibraryCatalog
    /// The fit scale the loupe measured, which Zoom to Fit draws at.
    var fitScale = 1.0

    /// What the "Preview data" pill means, as its tooltip and accessibility hint.
    static let previewHelp = "This window shows built-in sample data, not photos on disk."

    var body: some View {
        let zoom = model.loupeItem == nil ? 1 : model.loupeZoom.scale(fit: fitScale)
        ViewerStatusBar(zoom: zoom, size: model.statusSizeText) {
            if model.services.isPreview {
                Text("Preview data").accessibilityIdentifier("library.status.preview").statusPill(.warning)
                    .help(Self.previewHelp)
                    .accessibilityHint(Self.previewHelp)
            }
        }
    }
}
