// FlareApp.swift: Flare, the 2D animation app. Only the App and its Scene:
// one window group of FlareWindow (FlareWindow.swift) with the sidebar
// commands and Flare's menus (FlareCommands). Views only read FlareWorkspace
// and call its methods; all state lives in FlareModel (scripts/ci checks this).
//
// File-flow (FL-2): the scene takes part in switching (`.suiteApp`), File
// gets the suite's Open Recent ▸ and Open In ▸ (SuiteFileCommands, in
// FlareCommands), and the stage takes drops (`.suiteFileDrop`, FlareStage);
// all three read FlareShell's one documents bridge, which starts watching the
// suite's recents at launch (FlareAppDelegate).
import AppKit
import FlareModel
import SuiteModel
import SuiteShell
import SwiftUI

/// The process's documents bridge: the suite's recents and routing, on fakes for a `-FlareFixture` launch.
@MainActor enum FlareShell {
    static let bridge: SuiteDocumentsBridge = {
        let arguments = ProcessInfo.processInfo.arguments
        let services: SuiteServices = FlareLaunch(arguments: arguments).usesFakes
            ? .fake()
            : .live(support: SuiteLocations.supportFolder(arguments: arguments, home: NSHomeDirectory()),
                    app: .flare, arguments: arguments)
        return SuiteDocumentsBridge(app: .flare, services: services)
    }()

    /// The hand-off host: it accepts open and new, and refuses an SVG place until SVG import (E11).
    static let host = FlareWorkspace(services: .fake())
}

@main
struct FlareApp: App {
    @NSApplicationDelegateAdaptor private var delegate: FlareAppDelegate

    var body: some Scene {
        WindowGroup { FlareWindow() }
            // Fits a 1024 x 768 screen (the CI runner's) with the inspector in full.
            .defaultSize(width: 1000, height: 700)
            .commands {
                SidebarCommands()
                FlareCommands()
            }
            .suiteApp(.flare, host: FlareShell.host)
    }
}

/// Starts watching the suite's recents once the app has launched.
@MainActor final class FlareAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { await FlareShell.bridge.watch() }
    }
}
