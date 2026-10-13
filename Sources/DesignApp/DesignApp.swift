// DesignApp.swift: Design, the vector and UI design app. One window per file,
// laid out as SuiteUI's EditorShell (top bar, tool rail, canvas with rulers, the
// Properties | Layers panel, status line) in a window whose title bar is hidden
// so the top bar takes its place. DesignWindow holds the state; File > New File
// (DesignFileCommands) and the Page menu (DesignCommands) reach it through
// focused scene values. Views only read DesignWorkspace and call its methods;
// all state lives in DesignModel (scripts/ci checks this).
import SwiftUI

@main
struct DesignApp: App {
    var body: some Scene {
        WindowGroup { DesignWindow() }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1280, height: 820)
            .commands {
                DesignFileCommands()
                DesignCommands()
            }
    }
}
