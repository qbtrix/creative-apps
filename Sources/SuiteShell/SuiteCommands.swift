// SuiteCommands.swift: the menu commands every suite process adds. For now
// Window > Switch To with Home (Control-Command-0) and the five apps
// (Control-Command-1 to 5), each disabled with "Not connected yet
// (switching)." until switching (SW-3c) wires them to the running apps.
// The initializer's signature is the one switching keeps.
import SuiteModel
import SwiftUI

/// Window > Switch To, the shared menu every app and the launcher add.
public struct SuiteCommands: Commands {
    public init(app: SuiteApp = .launcher) {}

    public var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            Menu("Switch To") {
                Button("Home") {}.keyboardShortcut("0", modifiers: [.control, .command])
                    .disabled(true).help(SuiteIdentity.notConnected("switching"))
                Button("Flare") {}.keyboardShortcut("1", modifiers: [.control, .command])
                    .disabled(true).help(SuiteIdentity.notConnected("switching"))
                Button("Design") {}.keyboardShortcut("2", modifiers: [.control, .command])
                    .disabled(true).help(SuiteIdentity.notConnected("switching"))
                Button("Photo") {}.keyboardShortcut("3", modifiers: [.control, .command])
                    .disabled(true).help(SuiteIdentity.notConnected("switching"))
                Button("Library") {}.keyboardShortcut("4", modifiers: [.control, .command])
                    .disabled(true).help(SuiteIdentity.notConnected("switching"))
                Button("Halo") {}.keyboardShortcut("5", modifiers: [.control, .command])
                    .disabled(true).help(SuiteIdentity.notConnected("switching"))
            }
        }
    }
}
