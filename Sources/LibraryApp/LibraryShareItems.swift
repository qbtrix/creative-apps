// LibraryShareItems.swift: Library's Share (share-sheet SH-4, packet
// docs/blueprints/library/features/share-sheet.md): SuiteUI's ShareButton as a
// glass pill (HoverButtonStyle(glass:)) in a band above the grid, so it never
// covers a photo, and over the loupe's top-trailing corner; and File > Share…. Both
// prepare through `LibraryCatalog.prepareShare` (`file.share-prepare`), the
// copies landing in `Share/<run>` beside the catalog file; while
// `shareHelp` says why Share can't run (nothing selected, an export running,
// or the SH-1 stubs), both are off with that reason. The button is rebuilt
// for each selection, so files prepared for one are never offered for the next.
import Foundation
import LibraryModel
import SuiteUI
import SwiftUI

extension LibraryWindow {
    /// File > Share…: off with `shareHelp` until SH-5 opens the system's share menu for the selection.
    var shareMenu: LibraryMenu.Share {
        LibraryMenu.Share(share: nil, help: model.shareHelp ?? LibraryMenu.Share.menuNotBuilt)
    }
}

extension View {
    /// The Share pill (`suite.share`) for `model`'s selection: in a band of its own above the grid (`inset`), so it
    /// never covers a photo, else over the loupe's top-trailing corner, opposite its Grid pill.
    func libraryShare(_ model: LibraryCatalog, inset: Bool = false) -> some View {
        let pill = LibrarySharePill(model: model)
        return Group {
            if inset {
                safeAreaInset(edge: .top, alignment: .trailing, spacing: 0) { pill }
            } else {
                overlay(alignment: .topTrailing) { pill }
            }
        }
    }
}

/// SuiteUI's ShareButton as a glass pill with hover and pressed states, like the loupe's Grid pill.
private struct LibrarySharePill: View {
    let model: LibraryCatalog

    var body: some View {
        let help = model.shareHelp
        ShareButton(help: help) {
            let support = CatalogStore().folder.path(percentEncoded: false)
            let files = try await model.prepareShare(support: support, run: UUID().uuidString)
            return files.map { URL(fileURLWithPath: $0) }
        }
        .buttonStyle(HoverButtonStyle(glass: true))
        .id(model.exportTargets.map(\.id))
        .libraryControl(id: "suite.share", enabled: help == nil, help: help)
        .padding(SuiteSpacing.l)
    }
}
