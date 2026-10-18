// DesignEditMenu.swift: the Design items of the Edit menu, placed after the
// system's own Cut, Copy, Paste, Delete and Select All, which stay so they keep
// working in text fields: Duplicate (⌘D). The system's Delete removes the
// selected layer: the canvas and the Layers list hook it (designPasteboardCommands),
// so Edit holds one Delete, not a second look-alike. Also the MenuCommand init
// every selection command's menu item takes: SuiteUI's item with its SF
// Symbol sending DesignIntent.command, disabled while the Model's help for it
// says why, with that help as its tooltip.
import DesignModel
import SwiftUI

/// Edit: Duplicate.
struct DesignEditItems: View {
    let menu: DesignMenu

    var body: some View {
        MenuCommand(
            menu: menu, title: "Duplicate", systemImage: "plus.square.on.square", command: .duplicate,
            shortcut: KeyboardShortcut("d"))
    }
}

extension MenuCommand {
    /// One selection command as a menu item: on when the Model has no help for it, else off with that help.
    init(menu: DesignMenu, title: String, systemImage: String, command: DesignCommand, shortcut: KeyboardShortcut? = nil) {
        let help = menu.help(command)
        self.init(title, systemImage: systemImage, shortcut: shortcut, help: help ?? "", isEnabled: help == nil) {
            menu.perform(.command(command))
        }
    }
}
