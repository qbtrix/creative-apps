// LibraryApp.swift: Library, the photo catalog app. The scene is one
// Window of LibraryWindow (decision D2: one catalog, so one window; closing
// it quits) with the menu bar (LibraryCommands), which reaches the window
// through a focused value. Views only read LibraryCatalog and call its
// methods; all state lives in LibraryModel (scripts/ci checks this).
import LibraryModel
import SuiteUI
import SwiftUI

@main
struct LibraryApp: App {
    var body: some Scene {
        Window("Library", id: "library") { LibraryWindow() }
            .commands { LibraryCommands() }
    }
}
