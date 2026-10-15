// LibraryApp.swift: Library, the photo catalog app. The scene is one
// WindowGroup of LibraryWindow with the menu bar (LibraryCommands), which
// reaches the window through a focused value. Views only read LibraryCatalog
// and call its methods; all state lives in LibraryModel (scripts/ci checks this).
import LibraryModel
import SuiteUI
import SwiftUI

@main
struct LibraryApp: App {
    var body: some Scene {
        WindowGroup { LibraryWindow() }
            .commands { LibraryCommands() }
    }
}
