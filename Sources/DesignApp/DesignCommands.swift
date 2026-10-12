// DesignCommands.swift: Design's Page menu in the menu bar: Add Page and
// Delete Page. The window publishes each action as a focused scene value, nil
// when it is unavailable (no file open; the last page), so the items disable
// rather than hide.
import SwiftUI

extension FocusedValues {
    /// Adds a page to the focused window's file; nil with no file open.
    @Entry var designAddPage: (@MainActor () -> Void)?
    /// Deletes the focused window's selected page; nil when it is the last one.
    @Entry var designDeletePage: (@MainActor () -> Void)?
}

struct DesignCommands: Commands {
    @FocusedValue(\.designAddPage) private var addPage
    @FocusedValue(\.designDeletePage) private var deletePage

    var body: some Commands {
        CommandMenu("Page") {
            DesignPageMenu(addPage: addPage, deletePage: deletePage)
        }
    }
}

/// The Page menu's items; a nil action shows its item disabled.
struct DesignPageMenu: View {
    let addPage: (@MainActor () -> Void)?
    let deletePage: (@MainActor () -> Void)?

    var body: some View {
        Button("Add Page", systemImage: "doc.badge.plus") { addPage?() }
            .disabled(addPage == nil)
        Button("Delete Page", systemImage: "trash") { deletePage?() }
            .disabled(deletePage == nil)
    }
}
