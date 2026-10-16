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

@main
struct DesignApp: App {
    var body: some Scene {
        WindowGroup(id: DesignLaunch.windowID, for: DesignLaunch.self) { launch in
            DesignWindow(launch: launch.wrappedValue)
        }
        .defaultSize(width: 1000, height: 700)
        .defaultLaunchBehavior(.presented)
        .commands {
            SidebarCommands()
            DesignCommands()
        }
    }
}
