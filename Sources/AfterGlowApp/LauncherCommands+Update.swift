// LauncherCommands+Update.swift: the updater's launcher menu (blueprint
// suite.md 6.2): AfterGlow > Check for Updates…, after About AfterGlow,
// disabled with "Not connected yet (updater)." until the updater wires it.
// Out of the beta: no scene builds it (no-placeholders NP-2), so the app menu
// shows no item that can't act; the updater adds it back to AfterGlowApp's
// home scene once it checks for updates.
import SuiteModel
import SwiftUI

struct LauncherCommandsUpdate: Commands {
    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {}.disabled(true).help(SuiteIdentity.notConnected("updater"))
        }
    }
}
