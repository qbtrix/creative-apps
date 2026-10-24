// FlareApp.swift: Flare, the 2D animation app. Only the App and its Scene:
// one window group of FlareWindow (FlareWindow.swift) with the sidebar
// commands and Flare's menus (FlareCommands). Views only read FlareWorkspace
// and call its methods; all state lives in FlareModel (scripts/ci checks this).
//
// File-flow (FL-2): the scene takes part in switching (`.suiteApp`), File
// gets the suite's Open Recent ▸ and Open In ▸ (SuiteFileCommands, in
// FlareCommands), and the stage takes drops (`.suiteFileDrop`, FlareStage;
// the empty state opens a dropped .flare itself, FlareCanvas); all three read
// FlareShell's one documents bridge, which starts watching the suite's recents at launch
// (FlareAppDelegate). Every hand-off reaches FlareShell.host, a
// FlareDocumentHost that hands each dropped or reopened animation to
// FlareShell.openQueue (SuiteUI's SuiteOpenQueue): an empty window opens it in
// place, else it opens in a new window, even on a cold launch that shows none.
// Editor menus (EM-5): `.suiteEditor` adds Window's Switch To ▸ and AI
// Access… and the suite's Help group; FlareLive's channel answers live
// `afterglow` commands on the active window's animation. The delegate is a
// SuiteAppDelegate, so a Dock click with no window open opens one through
// the window group's id (`.suiteReopenWindow`), and opened files reach the host.
import AppKit
import FlareModel
import SuiteModel
import SuiteShell
import SuiteUI
import SwiftUI

/// The process's documents bridge: the suite's recents and routing, on fakes for a `-FlareFixture` launch.
@MainActor enum FlareShell {
    static let bridge: SuiteDocumentsBridge = {
        let arguments = ProcessInfo.processInfo.arguments
        let support = SuiteLocations.supportFolder(arguments: arguments, home: NSHomeDirectory())
        let fakes = FlareLaunch(arguments: arguments).usesFakes
        // A journey's `-SuiteFixture` goes into the store before the bridge's first read (#4604).
        if !fakes { FlareLaunch.seedSuiteFixture(arguments: arguments, support: support) }
        let services: SuiteServices = fakes ? .fake() : .live(support: support, app: .flare, arguments: arguments)
        return SuiteDocumentsBridge(app: .flare, services: services)
    }()

    /// The animations waiting for a window: an empty window takes one in place, else a new window opens.
    static let openQueue = SuiteOpenQueue(windowID: "flare")

    /// The hand-off host: an open hand-off opens each animation through `openQueue`; an SVG place is refused
    /// until SVG import (E11).
    static let host = FlareDocumentHost { requests in
        await MainActor.run {
            for case .open(let path) in requests { openQueue.open(URL(fileURLWithPath: path)) }
        }
    }
}

@main
struct FlareApp: App {
    @NSApplicationDelegateAdaptor private var delegate: FlareAppDelegate

    var body: some Scene {
        WindowGroup(id: FlareShell.openQueue.windowID) {
            FlareWindow().suiteReopenWindow(id: FlareShell.openQueue.windowID)
        }
            // Fits a 1024 x 768 screen (the CI runner's) with the inspector in full.
            .defaultSize(width: 1000, height: 700)
            .commands {
                SidebarCommands()
                FlareCommands()
            }
            .suiteEditor(.flare, host: FlareShell.host, live: FlareLive.channel)
            .suiteOpenQueue(FlareShell.openQueue)
    }
}

/// The suite's delegate (hand-offs, Dock reopen) that also starts watching the suite's recents once the app has launched.
@MainActor final class FlareAppDelegate: SuiteAppDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await FlareShell.bridge.watch() }
    }
}
