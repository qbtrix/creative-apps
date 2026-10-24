// LibraryShareItems.swift: Library's Share (share-sheet SH-4, packet
// docs/blueprints/library/features/share-sheet.md): SuiteUI's ShareButton as
// an item of the grid's toolbar row (after Export…), and as a glass pill over
// the loupe's top-trailing corner, opposite its Grid pill; and File > Share….
// Both prepare through `LibraryCatalog.prepareShare` (`file.share-prepare`), the
// copies landing in `Share/<run>` beside the catalog file; while
// `shareHelp` says why Share can't run (nothing selected, an export running,
// or no exporter), both are off with that reason. The button is rebuilt
// for each selection, so files prepared for one are never offered for the next.
import Foundation
import LibraryModel
import SuiteUI
import SwiftUI

extension LibraryWindow {
    /// File > Share…: the system's share sheet for the selection's copies (LibraryWindow+Share.swift); off with
    /// `shareHelp` while Share can't run.
    var shareMenu: LibraryMenu.Share {
        let help = model.shareHelp
        return LibraryMenu.Share(share: enabled(help == nil) { shareFromMenu() }, help: help)
    }
}

extension View {
    /// The Share pill (`suite.share`) over this view's top-trailing corner, for `model`'s selection.
    func libraryShare(_ model: LibraryCatalog) -> some View {
        overlay(alignment: .topTrailing) {
            LibraryShareItem(model: model)
                .buttonStyle(HoverButtonStyle(glass: true))
                .padding(SuiteSpacing.l)
        }
    }
}

/// SuiteUI's ShareButton (`suite.share`) for `model`'s selection; the host gives it its look.
struct LibraryShareItem: View {
    let model: LibraryCatalog

    var body: some View {
        let help = model.shareHelp
        ShareButton(help: help) {
            let support = CatalogStore().folder.path(percentEncoded: false)
            let files = try await model.prepareShare(support: support, run: UUID().uuidString)
            return files.map { URL(fileURLWithPath: $0) }
        }
        .id(model.exportTargets.map(\.id))
        .libraryControl(id: "suite.share", enabled: help == nil, help: help)
    }
}
