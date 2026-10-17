// FlareApp.swift: Flare, the 2D animation app. Only the App and its Scene:
// one window group of FlareWindow (FlareWindow.swift) with the sidebar
// commands and Flare's menus (FlareCommands). Views only read FlareWorkspace
// and call its methods; all state lives in FlareModel (scripts/ci checks this).
import SwiftUI

@main
struct FlareApp: App {
    var body: some Scene {
        WindowGroup { FlareWindow() }
            // Fits a 1024 x 768 screen (the CI runner's) with the inspector in full.
            .defaultSize(width: 1000, height: 700)
            .commands {
                SidebarCommands()
                FlareCommands()
            }
    }
}
