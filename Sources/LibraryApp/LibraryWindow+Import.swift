// LibraryWindow+Import.swift: the import area, a stub until the import
// feature fills it: File > Import Folder… and the import notice's actions,
// import on launch, and import once the catalog has been restored.
import LibraryModel
import SwiftUI

final class ImportAreaState {}

extension LibraryWindow {
    var fileMenu: LibraryMenu.File { LibraryMenu.File() }

    /// Called once from the window's `.task`.
    func importAreaLaunch() {}

    /// Called when `model.catalogState` changes (the restore finished).
    func importAreaCatalogReady() {}
}
