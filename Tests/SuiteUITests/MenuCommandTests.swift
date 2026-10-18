// MenuCommandTests.swift: SuiteUI's MenuCommand, the one menu item every app
// builds its menus from: it keeps the title, symbol, key equivalent and help
// it is given, runs `perform`, and is enabled unless told otherwise. macOS only.
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct MenuCommandTests {
    @Test func itKeepsWhatItIsGivenAndRunsPerform() {
        var ran = 0
        let item = MenuCommand("Duplicate", systemImage: "plus.square.on.square", shortcut: KeyboardShortcut("d"),
                               help: "Duplicate the selection.") { ran += 1 }
        #expect(item.title == "Duplicate" && item.systemImage == "plus.square.on.square")
        #expect(item.shortcut == KeyboardShortcut("d") && item.help == "Duplicate the selection.")
        #expect(item.isEnabled)
        item.perform()
        #expect(ran == 1)
        let off = MenuCommand("Paste", help: "Nothing to paste.", isEnabled: false) {}
        #expect(!off.isEnabled && off.systemImage == nil && off.shortcut == nil)
    }
}
