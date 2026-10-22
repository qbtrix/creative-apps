// LibraryApp.swift: Library, the photo catalog app. The scene is one
// Window of LibraryWindow (decision D2: one catalog, so one window; closing
// it quits) with the menu bar (LibraryCommands), which reaches the window
// through a focused value, and the system's View > Show/Hide Inspector
// (InspectorCommands), which toggles SuiteWindow's `.inspector`. Views only read LibraryCatalog and call its
// methods; all state lives in LibraryModel (scripts/ci checks this).
// File-flow (LF-2): the scene takes part in switching (`.suiteApp`), File
// gets the suite's Open Recent ▸ and Open In ▸ (SuiteFileCommands), and the
// window takes drops; all three read the process's one documents bridge.
import Foundation
import LibraryModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

/// The process's documents bridge: the suite's recents and routing, on fakes for a `-LibraryFixture` launch.
@MainActor enum LibraryShell {
    static let bridge: SuiteDocumentsBridge = {
        let arguments = ProcessInfo.processInfo.arguments
        let services: SuiteServices = LibraryLaunch(arguments: arguments).fixture == nil
            ? .live(support: SuiteLocations.supportFolder(arguments: arguments, home: NSHomeDirectory()),
                    app: .library, arguments: arguments)
            : .fake()
        return SuiteDocumentsBridge(app: .library, services: services)
    }()

    /// The hand-off host; the catalog's file-flow answers don't depend on its photos until LF-3.
    static let host = LibraryCatalog(services: .fake())
}

@main
struct LibraryApp: App {
    var body: some Scene {
        Window("Library", id: "library") { LibraryWindow() }
            .commands {
                LibraryCommands()
                LibraryBackupCommands()
                SuiteFileCommands(app: .library, bridge: LibraryShell.bridge)
                InspectorCommands()
            }
            .suiteApp(.library, host: LibraryShell.host)
    }
}
