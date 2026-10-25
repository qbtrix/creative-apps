// HaloFileMenu.swift: Halo's items in the File menu. After the system's
// New Window ⌘N, which stays so closing the last window never leaves Halo
// without one (#1081): New Composition… and Open… ⌘O, then the suite's Open
// Recent ▸ and Open In ▸ (SuiteFileCommands over HaloShell's bridge, file-flow
// HF-2; Open In gets the saved project). After the system's Close: Save ⌘S, Save As…
// ⇧⌘S, then Place… ⇧⌘P (HaloPlaceMenuAdapter, through the focused window's
// `haloPlace`), Render… ⇧⌘R (Halo's export) and Render Frame ⌘R. Each other
// item is built from its catalog spec (HaloMenuTarget.item), sends its HaloCommand
// through the focused window and is disabled with the spec's reason as help.
import HaloModel
import SuiteShell
import SuiteUI
import SwiftUI

struct HaloFileMenu: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform
    @FocusedValue(\.haloPlace) private var place

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            target.item(.newComposition, systemImage: "plus")
            target.item(.open, systemImage: "folder", shortcut: KeyboardShortcut("o"))
        }
        SuiteFileCommands(app: .halo, bridge: HaloShell.bridge, document: model?.suiteDocument)
        CommandGroup(after: .saveItem) {
            target.item(.save, systemImage: "square.and.arrow.down", shortcut: KeyboardShortcut("s"))
            target.item(.saveAs, shortcut: KeyboardShortcut("s", modifiers: [.command, .shift]))
            Divider()
            HaloPlaceMenuAdapter(model: model, place: place)
            target.item(.openRenderSheet, systemImage: "film", shortcut: KeyboardShortcut("r", modifiers: [.command, .shift]))
            target.item(.renderFrame, systemImage: "photo", shortcut: KeyboardShortcut("r"))
        }
    }
}
