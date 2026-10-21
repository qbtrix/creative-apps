// HaloEditMenu.swift: Halo's Undo ⌘Z and Redo ⇧⌘Z in place of the system
// pair, titled for the step they act on by `HaloProject.title(for:)` ("Undo
// New Layer"), sent through the focused window and disabled with the Model's
// reason as help (HaloMenuTarget.item, from the catalog spec). The system's pasteboard items stay, so Cut,
// Copy, Paste and Select All still work in text fields.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloEditMenu: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            target.item(.undo, shortcut: KeyboardShortcut("z"))
            target.item(.redo, shortcut: KeyboardShortcut("z", modifiers: [.command, .shift]))
        }
    }
}
