// LibraryShareItems.swift: Library's Share (share-sheet SH-4, packet
// docs/blueprints/library/features/share-sheet.md): SuiteUI's ShareButton in
// the grid's and the loupe's top-trailing corner, and File > Share…. Both
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
    /// The Share button (`suite.share`) over this view's top-trailing corner, for `model`'s selection.
    func libraryShare(_ model: LibraryCatalog) -> some View {
        let help = model.shareHelp
        return overlay(alignment: .topTrailing) {
            GlassPanel {
                ShareButton(help: help) {
                    let support = CatalogStore().folder.path(percentEncoded: false)
                    let files = try await model.prepareShare(support: support, run: UUID().uuidString)
                    return files.map { URL(fileURLWithPath: $0) }
                }
            }
            .id(model.exportTargets.map(\.id))
            .libraryControl(id: "suite.share", enabled: help == nil, help: help)
            .padding(SuiteSpacing.l)
        }
    }
}
