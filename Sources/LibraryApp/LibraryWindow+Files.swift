// LibraryWindow+Files.swift (catalog-files LC-3): Remove from Catalog… confirms with the count, then runs
// `photo.remove-from-catalog`; Locate… asks for the new file, then runs `photo.relink`, both through
// `LibraryCatalog.fileCommands` (disabled with its reason on the LC-1 stubs). The dialog's state is the
// modifier's own @State, so asking re-renders no window body.
import AppKit
import LibraryModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// The file actions the menus and the badge read: each nil while its why says why it can't run.
struct LibraryFilesActions {
    var remove: LibraryMenu.Action?
    var removeWhy = LibraryCatalog.catalogFilesHelp
    var locate: LibraryMenu.Action?
    var locateWhy = LibraryCatalog.catalogFilesHelp
}

extension FocusedValues {
    @Entry var libraryFiles: LibraryFilesActions?
}

extension EnvironmentValues {
    @Entry var libraryFiles = LibraryFilesActions()
}

@Observable final class FilesAreaState {
    var confirming = false
    var count = 0
    var message: String?
}

/// Publishes the file actions and presents Remove from Catalog's confirm.
struct LibraryFilesArea: ViewModifier {
    let catalog: LibraryCatalog
    let remove: @MainActor () throws(CatalogError) -> Void
    let relink: @MainActor (String, String) throws(CatalogError) -> Void
    @State private var state = FilesAreaState()

    func body(content: Content) -> some View {
        let actions = self.actions
        content
            .focusedSceneValue(\.libraryFiles, actions)
            .environment(\.libraryFiles, actions)
            .confirmationDialog(LibraryCatalog.removeConfirmTitle(count: state.count), isPresented: confirming,
                                titleVisibility: .visible) {
                if let spec = LibraryCatalog.fileSpec("photo.remove-from-catalog") {
                    MenuCommand(spec, on: catalog, role: .destructive) { perform() }
                        .accessibilityIdentifier("library.remove.confirm")
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(state.message ?? LibraryCatalog.removeConfirmMessage)
            }
    }

    private var why: (remove: String?, relink: String?) {
        (LibraryCatalog.fileCommands.availability("photo.remove-from-catalog", on: catalog).why
            ?? (catalog.removeCount == 0 ? "Select the photos to remove." : nil),
         LibraryCatalog.fileCommands.availability("photo.relink", on: catalog).why
            ?? (catalog.locateTarget == nil ? "No photo is missing its file." : nil))
    }

    private var actions: LibraryFilesActions {
        let (removeWhy, relinkWhy) = why
        let shown = state, count = catalog.removeCount, target = catalog.locateTarget
        var actions = LibraryFilesActions()
        if let removeWhy { actions.removeWhy = removeWhy } else {
            actions.remove = { (shown.count, shown.message, shown.confirming) = (count, nil, true) }
        }
        if let relinkWhy { actions.locateWhy = relinkWhy } else if let target {
            actions.locate = { locate(target) }
        }
        return actions
    }

    private var confirming: Binding<Bool> {
        let shown = state
        return Binding<Bool>(get: { shown.confirming }, set: { (value: Bool) -> Void in shown.confirming = value })
    }

    /// Removes the selection; a refusal asks again with the reason.
    private func perform() {
        do { try remove() } catch {
            state.message = String(describing: error)
            state.confirming = true
        }
    }

    /// Asks for `id`'s new file, then relinks it (and its folder's other missing photos).
    private func locate(_ id: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Locate"
        panel.message = "Choose the photo's new file."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? relink(id, url.path(percentEncoded: false))
    }
}

extension LibraryWindow {
    var filesArea: LibraryFilesArea {
        LibraryFilesArea(
            catalog: model,
            remove: { () throws(CatalogError) -> Void in
                _ = try LibraryCatalog.fileCommands.run("photo.remove-from-catalog", params: .object([:]), on: &model)
            },
            relink: { (id: String, file: String) throws(CatalogError) -> Void in
                _ = try LibraryCatalog.fileCommands.run(
                    "photo.relink", params: .object(["id": .string(id), "file": .string(file)]), on: &model)
            })
    }
}
