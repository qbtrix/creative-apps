// LibraryMissingBadge.swift (catalog-files LC-3): the missing count and Locate… over the grid's corner, and
// the grid's file context menu. Per-cell badges wait on ThumbnailGrid (needs-ui). Values in, closures out.
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryMissingBadge: View {
    let model: LibraryCatalog
    let files: LibraryFilesActions

    var body: some View {
        let count = model.missingCount
        if count > 0 {
            GlassPanel {
                HStack(spacing: SuiteSpacing.m) {
                    Label(LibraryCatalog.missingBadgeTitle(count: count), systemImage: "exclamationmark.triangle")
                        .foregroundStyle(SuiteColor.stateWarning)
                        .accessibilityIdentifier("library.grid.missing")
                    MenuCommand("photo.relink", on: model, title: "Locate…", action: files.locate, reason: files.locateWhy)
                        .accessibilityIdentifier("library.missing.locate")
                }
            }
            .padding(SuiteSpacing.l)
        }
    }
}

/// The grid's context menu: Remove from Catalog… and Locate…, the Photo menu's items.
struct LibraryFilesContextMenu: View {
    let model: LibraryCatalog
    let files: LibraryFilesActions

    var body: some View {
        MenuCommand("photo.remove-from-catalog", on: model, title: "Remove from Catalog…", action: files.remove,
                    reason: files.removeWhy)
        MenuCommand("photo.relink", on: model, title: "Locate…", action: files.locate, reason: files.locateWhy)
    }
}
