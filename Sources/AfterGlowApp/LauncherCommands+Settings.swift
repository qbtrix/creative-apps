// LauncherCommands+Settings.swift: the settings feature's launcher menu
// (blueprint suite.md 6.2). AfterGlow > Settings… (Command-comma) is the
// Settings scene's own item and already opens SettingsView, so this stub
// doesn't replace it with a disabled copy: the group after it is empty until
// the settings feature adds its items (one per app pane, if any).
import SuiteModel
import SwiftUI

struct LauncherCommandsSettings: Commands {
    var body: some Commands {
        CommandGroup(after: .appSettings) {}
    }
}
