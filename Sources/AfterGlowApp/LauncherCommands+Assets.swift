// LauncherCommands+Assets.swift: the shared-assets feature's launcher menus
// (blueprint suite.md 6.2), each item disabled with "Not connected yet
// (shared-assets)." until the Assets page wires it. Edit: Cut, Copy, Paste
// (titled "Add from Clipboard") and Select All, replacing the system's
// clipboard group so each appears once (Delete comes from the home stub);
// Window: Assets ⌥⌘A, after Switch To.
import SuiteModel
import SwiftUI

struct LauncherCommandsAssets: Commands {
    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {}.keyboardShortcut("x")
                .disabled(true).help(SuiteIdentity.notConnected("shared-assets"))
            Button("Copy") {}.keyboardShortcut("c")
                .disabled(true).help(SuiteIdentity.notConnected("shared-assets"))
            Button("Add from Clipboard") {}.keyboardShortcut("v")
                .disabled(true).help(SuiteIdentity.notConnected("shared-assets"))
            Button("Select All") {}.keyboardShortcut("a")
                .disabled(true).help(SuiteIdentity.notConnected("shared-assets"))
        }
        CommandGroup(after: .windowArrangement) {
            Button("Assets") {}.keyboardShortcut("a", modifiers: [.option, .command])
                .disabled(true).help(SuiteIdentity.notConnected("shared-assets"))
        }
    }
}
