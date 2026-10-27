// HaloApp.swift: Halo, the motion graphics app. The app scene opens
// HaloWindow and registers Halo's menus: File (HaloFileMenu), Edit's Undo and
// Redo (HaloEditMenu), Composition (HaloCompositionCommands), Layer
// (HaloCommands) and Animation (HaloAnimationMenu). Every item sends a
// HaloCommand to the focused window's `haloPerform` and reads its project
// (`haloProject`) for its title and availability. A window opens at
// `-HaloWindowSize` when given (HaloLaunch), else at the suite's launch size;
// the flag also sets the frame once the window is up (HaloWindowSizer), since
// a saved frame from an earlier launch outranks the default size.
// Switching (A-HA-1, #865; editor menus EM-6): the scene is a suite editor
// (`.suiteEditor(.halo, host:, live:)` with the suite's app delegate): Window
// gets Switch To ▸ and AI Access… (SuiteCommands), Help is the suite's group
// in place of the system's empty Halo Help (#1018), and HaloLive's channel
// answers live `afterglow` commands on the active window's project. The
// window group has no id, so a Dock click with no window open takes the
// system's reopen, which opens one. A hand-off the host accepts
// (`.new`: New Composition; `.open` a .halo: open it) waits in HaloShell's
// inbox until a window takes it (HaloWindow+File.swift).
// File-flow (HF-2): File gets the suite's Open Recent ▸ and Open In ▸
// (SuiteFileCommands, in HaloFileMenu) in place of Halo's own Open Recent,
// and the viewer takes drops (`.suiteFileDrop`, HaloViewer); all three read
// HaloShell's one documents bridge, which starts watching the suite's
// recents at launch (HaloAppDelegate).
// Views only read HaloProject and call its methods; all state lives in
// HaloModel (scripts/ci checks this).
import HaloModel
import Observation
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

/// The hand-offs the host accepted that no window has run yet, oldest first.
@MainActor @Observable final class HaloHandOffInbox {
    private(set) var pending: [HaloCommand] = []

    func send(_ command: HaloCommand) { pending.append(command) }

    /// The pending commands, which leave the inbox.
    func take() -> [HaloCommand] {
        let taken = pending
        pending = []
        return taken
    }
}

/// The process's hand-off host, the inbox it delivers to, and the documents bridge: the suite's recents and
/// routing, on fakes for a `-HaloFixture` launch.
@MainActor enum HaloShell {
    static let bridge: SuiteDocumentsBridge = {
        let arguments = ProcessInfo.processInfo.arguments
        let services: SuiteServices = HaloLaunch.current.fixture == nil
            ? .live(support: SuiteLocations.supportFolder(arguments: arguments, home: NSHomeDirectory()),
                    app: .halo, arguments: arguments)
            : .fake()
        return SuiteDocumentsBridge(app: .halo, services: services)
    }()
    static let inbox = HaloHandOffInbox()
    static let host = HaloDocumentHost { command in
        await MainActor.run { HaloShell.inbox.send(command) }
    }
}

@main
struct HaloApp: App {
    @NSApplicationDelegateAdaptor private var delegate: HaloAppDelegate

    var body: some Scene {
        WindowGroup {
            HaloWindow()
                .environment(\.haloStyleRoute, .shared)
                .background {
                    if let size = HaloLaunch.current.windowSize { HaloWindowSizer(size: size).accessibilityHidden(true) }
                }
        }
            .defaultSize(HaloLaunch.current.windowSize ?? SuiteSize.windowLaunch)
            .commands {
                HaloFileMenu()
                HaloEditMenu()
                HaloCompositionCommands()
                HaloCommands()
                HaloAnimationMenu()
            }
            .suiteEditor(.halo, host: HaloShell.host, live: HaloLive.channel)
    }
}

/// Suite hand-offs (SuiteAppDelegate), and watching the suite's recents once the app has launched.
@MainActor final class HaloAppDelegate: SuiteAppDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await HaloShell.bridge.watch() }
    }
}
