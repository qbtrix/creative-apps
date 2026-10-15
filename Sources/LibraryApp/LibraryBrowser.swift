// LibraryBrowser.swift: the Library window's content: the photo grid
// (LibraryGrid), the loupe (LibraryLoupe), or an empty state. Values in,
// closures out; LibraryCatalog holds the state.
import LibraryModel
import SuiteUI
import SwiftUI

/// The photo grid, or the empty state whose button loads the samples until
/// import lands (L2); an empty collection in a non-empty catalog gets an empty
/// state that says how to fill it, with a button back to All Photos. In loupe
/// mode it shows the loupe's photo (LibraryLoupe) instead of the grid.
struct LibraryBrowser: View {
    let model: LibraryCatalog
    var onLoadSamples: @MainActor () -> Void = {}
    var onSelect: @MainActor (Set<String>) -> Void = { _ in }
    var onOpen: @MainActor (String) -> Void = { _ in }
    var onShowAll: @MainActor () -> Void = {}
    var onStep: @MainActor (Int) -> Void = { _ in }
    var onGrid: @MainActor () -> Void = {}

    var body: some View {
        if model.isEmpty {
            EmptyStateView(
                "No Photos", systemImage: "photo.stack",
                message: "Photos you import appear here, sorted by the date they were taken.",
                action: ToolbarAction("Load Sample Photos", systemImage: "photo.badge.plus", perform: onLoadSamples))
        } else if model.isSelectedCollectionEmpty, let collection = model.selectedCollection {
            EmptyStateView(
                "No Photos in \(collection.name)", systemImage: "photo.stack", message: collection.emptyMessage,
                action: collection.emptyActionTitle.map {
                    ToolbarAction($0, systemImage: "photo.on.rectangle.angled", perform: onShowAll)
                })
        } else if let photo = model.loupeItem, let position = model.loupePosition {
            LibraryLoupe(photo: photo, position: position, onStep: onStep, onGrid: onGrid)
        } else {
            LibraryGrid(model: model, onSelect: onSelect, onOpen: onOpen)
        }
    }
}
