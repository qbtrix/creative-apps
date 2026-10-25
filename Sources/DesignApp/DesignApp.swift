// DesignApp.swift: Design, the vector and UI design app. One window per file
// (Open never replaces a window's file; it opens another window),
// laid out as SuiteUI's SuiteWindow (pages and layers in the sidebar, the
// canvas with rulers, the floating tool palette and the status line, Properties
// in the inspector, the commands in the window toolbar). The window keeps its
// title bar and follows the system appearance; it opens at 1000 x 700, which
// fits the 1024 x 768 CI runner with the inspector in full, and View > Hide
// Sidebar (SidebarCommands) makes room on a small screen. DesignWindow holds
// the state; the menus in DesignCommands reach it through a focused scene
// value. Views only read
// DesignWorkspace and call its methods; all state lives in DesignModel
// (scripts/ci checks this).
//
// Editor menus (EM-4): the delegate is a SuiteAppDelegate and `.suiteEditor`
// adds Window > Switch To, AI Access… and the suite's Help group over
// DesignShell.host, and starts DesignShell.live, a live command channel over
// the key window's file (`afterglow run --live design`). A Dock click with no
// window open opens one (`.suiteReopenWindow`).
//
// Hand-offs: a .design opened from Finder, the home's Recent or another app's
// Open In, and a `.new` from the home's New Design or the welcome's Blank,
// reach DesignShell.host (a DesignDocumentHost), which hands each file or new
// file to DesignShell.openQueue (SuiteUI's SuiteOpenQueue): an empty window
// takes it in place, else it opens in a new window.
import DesignModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

/// What a new Design window starts with: a new file, a file to open, or nothing.
/// SwiftUI shows one window per distinct value, so each carries its own id: File >
/// New File with no window open, and Open from a window that already holds a
/// file, always open a fresh window and never front an old one. The window the
/// app opens at launch has no value and starts empty.
struct DesignLaunch: Codable, Hashable, Sendable {
    static let windowID = "design"

    var id = UUID()
    var startsNewFile = false
    var file: URL?
}

/// The suite's side of the app: the hand-off host and the live command channel.
@MainActor enum DesignShell {
    /// The files waiting for a window: an empty window takes one in place, else a new window opens.
    static let openQueue = SuiteOpenQueue(windowID: DesignLaunch.windowID)

    /// Design's hand-off host: an open or a new hands each file or new file to `openQueue`.
    static let host = host(opening: openQueue)

    /// A host that hands each opened file and new file to `queue` (tests pass their own queue).
    static func host(opening queue: SuiteOpenQueue) -> DesignDocumentHost {
        DesignDocumentHost { requests in
            await MainActor.run {
                for request in requests {
                    switch request {
                    case .open(let path): queue.open(URL(fileURLWithPath: path))
                    case .newFile: queue.openNew()
                    }
                }
            }
        }
    }

    /// The key window, which DesignWindow joins with `suiteLiveWindow`: its file, and where a command's result goes.
    static let front = LiveFront<DesignHeadless>()

    /// Live commands on the key window's file; a client runs only on a grant it already holds.
    static let live = LiveCommandChannel(
        app: SuiteApp.design.displayName,
        document: { front.document() },
        apply: { front.apply($0) },
        ask: { await AIAccessCenter.shared.ask($0) })
}

@main
struct DesignApp: App {
    @NSApplicationDelegateAdaptor private var delegate: SuiteAppDelegate

    var body: some Scene {
        WindowGroup(id: DesignLaunch.windowID, for: DesignLaunch.self) { launch in
            DesignWindow(launch: launch.wrappedValue)
                .suiteReopenWindow(id: DesignLaunch.windowID)
        }
        .defaultSize(width: 1000, height: 700)
        .defaultLaunchBehavior(.presented)
        .commands {
            SidebarCommands()
            DesignCommands()
        }
        .suiteEditor(.design, host: DesignShell.host, live: DesignShell.live)
    }
}
