// PhotoApp.swift: Photo, the raster editing app. One window per image, laid
// out as SuiteUI's EditorShell (top bar, tool rail, canvas with rulers, the
// Adjust | Layers panel, status line) in a window whose title bar is hidden so
// the top bar takes its place. PhotoWindow holds the state; the menus in
// PhotoCommands reach it through a focused scene value.
import SwiftUI

@main
struct PhotoApp: App {
    var body: some Scene {
        WindowGroup { PhotoWindow() }
            .windowStyle(.hiddenTitleBar)
            .defaultSize(width: 1280, height: 820)
            .commands { PhotoCommands() }
    }
}
