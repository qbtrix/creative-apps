// HaloFileMenu.swift: Halo's items in the File menu. In place of the system's
// New Window: New Composition…, Open… ⌘O and Open Recent ▸ (the project's
// recent files, newest first; a disabled item with its reason while there
// are none). After the system's Close: Save ⌘S, Save As…
// ⇧⌘S, then Render… ⇧⌘R (Halo's export) and Render Frame ⌘R. Each item sends
// its HaloCommand through the focused window and is disabled with the Model's
// reason as help (HaloMenuItem).
import HaloModel
import SwiftUI

struct HaloFileMenu: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            HaloMenuItem(command: .newComposition, target: target, systemImage: "plus")
            HaloMenuItem(command: .open, target: target, systemImage: "folder", shortcut: KeyboardShortcut("o"))
            HaloOpenRecentMenu(target: target)
        }
        CommandGroup(after: .saveItem) {
            HaloMenuItem(
                command: .save, target: target, systemImage: "square.and.arrow.down", shortcut: KeyboardShortcut("s"))
            HaloMenuItem(command: .saveAs, target: target, shortcut: KeyboardShortcut("s", modifiers: [.command, .shift]))
            Divider()
            HaloMenuItem(
                command: .openRenderSheet, target: target, systemImage: "film",
                shortcut: KeyboardShortcut("r", modifiers: [.command, .shift]))
            HaloMenuItem(command: .renderFrame, target: target, systemImage: "photo", shortcut: KeyboardShortcut("r"))
        }
    }
}

/// Open Recent ▸: one item per recent file. With none it is a plain disabled
/// item with the reason as help, not a submenu: the menu bar ignores
/// `.disabled` and `.help` on a `Menu` in a command group, so an empty
/// submenu would look enabled and open to nothing.
struct HaloOpenRecentMenu: View {
    let target: HaloMenuTarget

    var body: some View {
        let recent = target.model?.file.recent ?? []
        if recent.isEmpty {
            Button("Open Recent") {}
                .disabled(true)
                .help(target.help(for: .open) ?? "No recent projects.")
        } else {
            Menu("Open Recent") {
                ForEach(recent, id: \.path) { file in
                    HaloMenuItem(command: .openRecent(file.path), target: target, title: file.name)
                }
            }
        }
    }
}
