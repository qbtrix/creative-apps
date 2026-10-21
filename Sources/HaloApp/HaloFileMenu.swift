// HaloFileMenu.swift: Halo's items in the File menu. In place of the system's
// New Window: New Composition…, Open… ⌘O and Open Recent ▸ (the project's
// recent files, newest first; a disabled item with its reason while there
// are none). After the system's Close: Save ⌘S, Save As…
// ⇧⌘S, then Render… ⇧⌘R (Halo's export) and Render Frame ⌘R. Each item is
// built from its catalog spec (HaloMenuTarget.item), sends its HaloCommand
// through the focused window and is disabled with the spec's reason as help.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloFileMenu: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            target.item(.newComposition, systemImage: "plus")
            target.item(.open, systemImage: "folder", shortcut: KeyboardShortcut("o"))
            HaloOpenRecentMenu(target: target)
        }
        CommandGroup(after: .saveItem) {
            target.item(.save, systemImage: "square.and.arrow.down", shortcut: KeyboardShortcut("s"))
            target.item(.saveAs, shortcut: KeyboardShortcut("s", modifiers: [.command, .shift]))
            Divider()
            target.item(.openRenderSheet, systemImage: "film", shortcut: KeyboardShortcut("r", modifiers: [.command, .shift]))
            target.item(.renderFrame, systemImage: "photo", shortcut: KeyboardShortcut("r"))
        }
    }
}

/// Open Recent ▸: one item per recent file. With none it is a plain item, off
/// by the Open Recent spec with its reason as help, not a submenu: the menu bar ignores
/// `.disabled` and `.help` on a `Menu` in a command group, so an empty
/// submenu would look enabled and open to nothing.
struct HaloOpenRecentMenu: View {
    let target: HaloMenuTarget

    var body: some View {
        let recent = target.model?.file.recent ?? []
        if recent.isEmpty {
            target.item(.openRecent(""), title: "Open Recent")
        } else {
            Menu("Open Recent") {
                ForEach(recent, id: \.path) { file in
                    target.item(.openRecent(file.path), title: file.name)
                }
            }
        }
    }
}
