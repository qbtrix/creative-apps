// DesignEditMenu.swift: the Design items of the Edit menu, placed after the
// system's own Cut, Copy, Paste and Select All, which stay so they keep
// working in text fields: Duplicate (⌘D) and Delete Layer. Also
// DesignCommandItem, the one shape every selection command's menu item takes:
// a Button sending DesignIntent.command, disabled while the Model's help for
// it says why, with that help as its tooltip.
import DesignModel
import SwiftUI

/// Edit: Duplicate, then Delete Layer.
struct DesignEditItems: View {
    let menu: DesignMenu

    var body: some View {
        DesignCommandItem(menu: menu, title: "Duplicate", command: .duplicate, shortcut: KeyboardShortcut("d"))
        DesignDeleteLayerItem(menu: menu)
    }
}

/// One selection command as a menu item: on when the Model has no help for it, else off with that help.
struct DesignCommandItem: View {
    let menu: DesignMenu
    let title: String
    let command: DesignCommand
    var shortcut: KeyboardShortcut?

    var body: some View {
        let help = menu.help(command)
        Button(title) { menu.perform(.command(command)) }
            .keyboardShortcut(shortcut)
            .disabled(help != nil)
            .help(help ?? "")
    }
}
