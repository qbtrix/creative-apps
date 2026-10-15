// LibraryWindow+Persist.swift: the persist area, a stub until the persist
// feature fills it: restore the catalog on launch, save after each change,
// flush before the app quits, and Show Catalog in Finder.
import LibraryModel
import SwiftUI

final class PersistAreaState {}

extension LibraryWindow {
    var persistMenu: LibraryMenu.Persist { LibraryMenu.Persist() }

    /// Called once from the window's `.task`.
    func persistAreaLaunch() {}

    /// Called when `model.saveRevision` changes.
    func persistAreaChanged() {}

    /// Called when the app is about to quit.
    func persistAreaFlush() {}
}
