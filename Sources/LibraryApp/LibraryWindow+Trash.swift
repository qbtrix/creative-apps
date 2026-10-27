// LibraryWindow+Trash.swift: the trash area (cull-finish DR-3). Photo > Delete Rejected Photos… ⌥⌘⌫ asks
// once with the Model's `deleteRejectsMessage`: Move to Trash (destructive) calls `deleteRejects()`;
// Cancel is the default, so Return cancels. The presented flag is this modifier's @State, so asking
// re-renders no window body.
import LibraryModel
import SuiteUI
import SwiftUI

/// Publishes the menu item and presents the confirm.
struct LibraryTrashArea: ViewModifier {
    let title: String
    let help: String?
    let question: String
    let deleteRejects: LibraryMenu.Action
    /// Rejects `count` photos spread over the catalog: only the render budget's DEBUG hook calls it.
    let reject: @MainActor (Int) -> Void
    @State private var confirming = false
    #if DEBUG
    /// The render budget's way in: reject photos, then run Move to Trash, while the item is disabled on the stubs.
    @MainActor static var rejectHook: (@MainActor (Int) -> Void)?
    @MainActor static var confirmHook: LibraryMenu.Action?
    #endif

    /// The dialog's line under its question.
    static let detail = "You can put them back with Undo or from the Trash."

    func body(content: Content) -> some View {
        content
            .focusedSceneValue(\.libraryTrash, menu)
            .confirmationDialog(question, isPresented: $confirming, titleVisibility: .visible) {
                LibraryDeleteRejectsButtons(perform: deleteRejects)
            } message: {
                Text(Self.detail)
            }
            .onAppear { hook() }
    }

    private var menu: LibraryMenu.Trash {
        var action: LibraryMenu.Action?
        if help == nil { action = { confirming = true } }
        return LibraryMenu.Trash(deleteRejects: action, title: title, help: help)
    }

    private func hook() {
        #if DEBUG
        Self.rejectHook = reject
        Self.confirmHook = deleteRejects
        #endif
    }
}

/// The confirm's buttons: Move to Trash runs `perform`; Cancel is the default, so Return never trashes.
struct LibraryDeleteRejectsButtons: View {
    let perform: LibraryMenu.Action

    var body: some View {
        MenuCommand(
            LibraryCatalog.deleteRejectsControlSpec, on: LibraryDeleteRejectsControl(help: nil), title: "Move to Trash",
            role: .destructive) { perform() }
            .accessibilityIdentifier("library.trash.confirm")
        Button("Cancel", role: .cancel) {}
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("library.trash.cancel")
    }
}

extension LibraryWindow {
    /// The area on the window's catalog; every change goes through the Model's methods.
    var trashArea: LibraryTrashArea {
        LibraryTrashArea(
            title: model.deleteRejectsTitle, help: model.deleteRejectsHelp, question: model.deleteRejectsMessage,
            deleteRejects: { model.deleteRejects() },
            reject: { (count: Int) -> Void in
                let ids = model.items.map(\.id)
                let step = max(ids.count / max(count, 1), 1)
                let picked = ids.enumerated().filter { $0.offset % step == 0 }.prefix(count).map(\.element)
                model.select(Set(picked))
                model.setFlag(.reject)
            })
    }
}
