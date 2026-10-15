// HaloFileMenu.swift: Halo's items in the File menu. In place of the system's
// New Window: New Composition…, Open… ⌘O and Open Recent ▸ (the project's
// recent files, newest first). After the system's Close: Save ⌘S, Save As…
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

/// Open Recent ▸: one item per recent file; disabled with a reason when the list is empty.
struct HaloOpenRecentMenu: View {
    let target: HaloMenuTarget

    var body: some View {
        let recent = target.model?.file.recent ?? []
        Menu("Open Recent") {
            ForEach(recent, id: \.path) { file in
                HaloMenuItem(command: .openRecent(file.path), target: target, title: file.name)
            }
        }
        .disabled(recent.isEmpty)
        .help(recent.isEmpty ? target.help(for: .open) ?? "No recent projects." : "Open a recent project.")
    }
}
