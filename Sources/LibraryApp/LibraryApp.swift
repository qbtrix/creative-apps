// LibraryApp.swift: Library, the photo catalog app. The scene is one
// Window of LibraryWindow (decision D2: one catalog, so one window; closing
// it quits) with the menu bar (LibraryCommands), which reaches the window
// through a focused value, and the system's View > Show/Hide Inspector
// (InspectorCommands), which toggles SuiteWindow's `.inspector`. Views only read LibraryCatalog and call its
// methods; all state lives in LibraryModel (scripts/ci checks this).
// File-flow (LF-2): the scene takes part in switching (`.suiteApp`), File
// gets the suite's Open Recent ▸ and Open In ▸ (SuiteFileCommands), and the
// window takes drops; all three read the process's one documents bridge.
// Editor menus (EM-7): the delegate is a SuiteAppDelegate and `.suiteEditor`
// adds Window > Switch To, AI Access… and the suite's Help group, and starts
// LibraryShell.live, a live command channel over the window's catalog
// (`afterglow run --live library`). An open hand-off (the welcome's Open
// sample, a photo the home routes here) imports its photos (LibraryDocumentHost). Closing the window quits (D2), so a Dock
// click relaunches; `.suiteReopenWindow` opens the window if the app is still
// running with none.
// The window's loupe draws develop steps on the GPU (`\.libraryLoupeGPU`, suite-imaging IM-11).
// Launch empties the last session's share copies (share-sheet SH-5).
import Foundation
import LibraryModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

/// The process's documents bridge: the suite's recents and routing, on fakes for a `-LibraryFixture` launch.
@MainActor enum LibraryShell {
    /// The suite's services: live, or fakes for a `-LibraryFixture` launch. The export writer takes `metadata`.
    static let services: SuiteServices = {
        let arguments = ProcessInfo.processInfo.arguments
        return LibraryLaunch(arguments: arguments).fixture == nil
            ? .live(support: SuiteLocations.supportFolder(arguments: arguments, home: NSHomeDirectory()),
                    app: .library, arguments: arguments)
            : .fake()
    }()

    static let bridge = SuiteDocumentsBridge(app: .library, services: services)

    /// The hand-off host: an open or place hand-off's photos go to the window's catalog, or wait in
    /// `handedOff` until the window takes them (a hand-off that launched the app comes before it).
    static let host = LibraryDocumentHost { paths in
        await MainActor.run {
            if let receive { receive(paths) } else { handedOff += paths }
        }
    }
    static var handedOff: [String] = []
    static var receive: (@MainActor ([String]) -> Void)?

    /// How to read the window's catalog, and land a live result in it (LibraryWindow keeps both current).
    static var read: (@MainActor () -> LibraryCatalog)?
    static var take: (@MainActor (LibraryHeadless) -> Void)?

    /// Live commands on the window's catalog; a client runs only on a grant it already holds.
    static let live = LiveCommandChannel(
        app: SuiteApp.library.displayName,
        document: { () -> LibraryHeadless? in read.map { LibraryHeadless(catalog: $0()) } },
        apply: { (result: LibraryHeadless) in take?(result) },
        ask: { await AIAccessCenter.shared.ask($0) })
}

@main
struct LibraryApp: App {
    @NSApplicationDelegateAdaptor private var delegate: SuiteAppDelegate

    /// Empties the last session's share copies (`Share/` beside the catalog file, share-sheet SH-5); a folder that
    /// can't be emptied waits for the next launch.
    init() { try? SharePrep.cleanup(support: CatalogStore().folder.path(percentEncoded: false)) }

    var body: some Scene {
        Window("Library", id: "library") {
            LibraryWindow().suiteReopenWindow(id: "library").environment(\.libraryLoupeGPU, .shared)
        }
            .commands {
                LibraryCommands()
                LibraryBackupCommands()
                SuiteFileCommands(app: .library, bridge: LibraryShell.bridge)
                InspectorCommands()
            }
            .suiteEditor(.library, host: LibraryShell.host, live: LibraryShell.live)
    }
}
