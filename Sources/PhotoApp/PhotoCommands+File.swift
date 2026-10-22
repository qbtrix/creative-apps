// PhotoCommands+File.swift: Photo's File menu items: New Image, Open…, the
// suite's Open Recent ▸ and Open In ▸ (file-flow PF-2), Place…
// (PhotoPlace.swift), Close, Save, Save As…, Export…. Save, Save As and Export
// are off with no image. Close (Command-W) is the system's, which replacing
// `.saveItem` drops: it sends performClose: to the key window, so an unsaved
// window asks first (PhotoWindowCloseGuard). Open Recent and Open In are
// SuiteFileCommands over the process's documents bridge (PhotoShell): Open
// Recent lists Photo's files from the suite's one recents list, newest first,
// with Clear Menu, or a disabled "No Recent Files"; Open In hands the focused
// window's saved image to Library, or is off with its reason. Replacing
// `.newItem` drops nothing the system would show: a WindowGroup app has no
// Open Recent of its own.
import AppKit
import PhotoModel
import SuiteShell
import SuiteUI
import SwiftUI

extension PhotoCommands {
    @CommandsBuilder var fileMenu: some Commands {
        CommandGroup(replacing: .newItem) {
            menu.item("file.new", shortcut: KeyboardShortcut("n")) { menu.perform(.newImage) }
            menu.item("file.open", shortcut: KeyboardShortcut("o")) { menu.perform(.open) }
        }
        SuiteFileCommands(app: .photo, bridge: PhotoShell.bridge, document: menu.workspace.suiteDocument)
        CommandGroup(before: .saveItem) {
            menu.placeItem
        }
        CommandGroup(replacing: .saveItem) {
            // `.saveItem` holds the system's Close, so replacing it brings Close back here.
            Button("Close") { NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil) }
                .keyboardShortcut("w")
            menu.item("file.save", shortcut: KeyboardShortcut("s")) { menu.perform(.save) }
            menu.item("file.save-as", shortcut: KeyboardShortcut("s", modifiers: [.command, .shift])) { menu.perform(.saveAs) }
            menu.item("file.export", shortcut: KeyboardShortcut("e", modifiers: [.command, .shift])) {
                menu.perform(.export(.openSheet))
            }
        }
    }
}
