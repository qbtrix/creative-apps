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
// Design's stub hand-off host, and starts DesignShell.live, a live command
// channel over the key window's file (`afterglow run --live design`). A Dock
// click with no window open opens one (`.suiteReopenWindow`).
import DesignModel
import SuiteModel
import SuiteShell
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
    /// Design's hand-off host, the stub that opens nothing until DF-3.
    static let host = DesignDocument(pages: [])

    /// The key window: its id, its file and where its intents go (DesignWindow keeps it current).
    static var front: (id: UUID, model: @MainActor () -> DesignWorkspace, perform: DesignPerform)?

    /// Live commands on the key window's file; a client runs only on a grant it already holds.
    static let live = LiveCommandChannel(
        app: SuiteApp.design.displayName,
        document: { () -> DesignHeadless? in front.map { DesignHeadless($0.model()) } },
        apply: { (result: DesignHeadless) in front?.perform(.adoptLive(result.workspace)) },
        ask: { _ in .deny })
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
