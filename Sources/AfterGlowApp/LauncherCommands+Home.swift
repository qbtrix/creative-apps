// LauncherCommands+Home.swift: the home feature's launcher menus (blueprint
// suite.md 6.2), each item disabled with "Not connected yet (home)." until
// the home wires it. File: New ▸ (replacing the system's New), Open… ⌘O and
// Open Recent ▸; Edit: Delete, titled for the home page ("Remove from
// Recents"), after the clipboard group the assets stub owns; View: Show
// Sidebar, Show Inspector ⌥⌘I and the thumbnail sizes, before the system's
// Enter Full Screen. No SidebarCommands, so Show Sidebar appears once.
import SuiteModel
import SwiftUI

struct LauncherCommandsHome: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Menu("New") {
                Button("New Animation") {}.disabled(true).help(SuiteIdentity.notConnected("home"))
                Button("New Design") {}.disabled(true).help(SuiteIdentity.notConnected("home"))
                Button("New Image") {}.disabled(true).help(SuiteIdentity.notConnected("home"))
                Button("Import Photos…") {}.disabled(true).help(SuiteIdentity.notConnected("home"))
                Button("New Composition") {}.disabled(true).help(SuiteIdentity.notConnected("home"))
            }
            Button("Open…") {}.keyboardShortcut("o")
                .disabled(true).help(SuiteIdentity.notConnected("home"))
            Menu("Open Recent") {
                Button("Clear Menu") {}.disabled(true).help(SuiteIdentity.notConnected("home"))
            }
        }
        CommandGroup(after: .pasteboard) {
            Button("Remove from Recents") {}.disabled(true).help(SuiteIdentity.notConnected("home"))
        }
        CommandGroup(before: .sidebar) {
            Button("Show Sidebar") {}.disabled(true).help(SuiteIdentity.notConnected("home"))
            Button("Show Inspector") {}.keyboardShortcut("i", modifiers: [.option, .command])
                .disabled(true).help(SuiteIdentity.notConnected("home"))
            Divider()
            Button("Larger Thumbnails") {}.keyboardShortcut("+")
                .disabled(true).help(SuiteIdentity.notConnected("home"))
            Button("Smaller Thumbnails") {}.keyboardShortcut("-")
                .disabled(true).help(SuiteIdentity.notConnected("home"))
        }
    }
}
