// LibraryCommands.swift: File > Load Sample Photos, View > Sort By and View >
// Larger and Smaller Thumbnails, fed by the focused window's LibraryMenu. With
// no window focused, or at a size limit, the items disable rather than hide.
import LibraryModel
import SwiftUI

/// What the menu bar reads from and calls on the focused window.
struct LibraryMenu {
    let sort: LibrarySort
    let loadSamples: @MainActor () -> Void
    let setSort: @MainActor (LibrarySort) -> Void
    let larger: (@MainActor () -> Void)?
    let smaller: (@MainActor () -> Void)?
}

extension FocusedValues {
    @Entry var libraryMenu: LibraryMenu?
}

struct LibraryCommands: Commands {
    @FocusedValue(\.libraryMenu) private var menu

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Load Sample Photos", systemImage: "photo.badge.plus") { menu?.loadSamples() }
                .disabled(menu == nil)
        }
        CommandGroup(before: .toolbar) {
            Picker("Sort By", selection: Binding(get: { menu?.sort ?? .captureDate }, set: { menu?.setSort($0) })) {
                ForEach(LibrarySort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .disabled(menu == nil)
            Button("Larger Thumbnails", systemImage: "plus.magnifyingglass") { menu?.larger?() }
                .keyboardShortcut("+")
                .disabled(menu?.larger == nil)
            Button("Smaller Thumbnails", systemImage: "minus.magnifyingglass") { menu?.smaller?() }
                .keyboardShortcut("-")
                .disabled(menu?.smaller == nil)
            Divider()
        }
    }
}
