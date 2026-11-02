// HaloEditMenu.swift: Halo's Undo ⌘Z and Redo ⇧⌘Z in place of the system
// pair, titled for the step they act on by `HaloProject.title(for:)` ("Undo
// New Layer"), sent through the focused window and disabled with the Model's
// reason as help (HaloMenuTarget.item, from the catalog spec). The pasteboard
// group is Halo's own (clipboard-interop CB-10), so there is one Paste: Cut ⌘X,
// Copy ⌘C, Copy Frame ⌥⌘C, Paste ⌘V and Select All ⌘A. While a text field has
// focus, Cut, Copy, Paste and Select All give way to it (SuiteUI's
// givingWay), so fields edit as anywhere. Otherwise every item is built from
// HaloEditMenuSpecs's specs: Cut, Copy and Select All are off with a
// reason (Halo copies frames, not layers, yet), except that while the timeline
// strip has focus (its FocusedValues.timelineSelectAll) ⌘A is Select All Keys,
// as in Flare: a disabled ⌘A item swallowed the key, so the strip's own
// selectAll: never ran (#5949). Copy Frame follows the
// catalog's `edit.copy-frame`, and Paste the catalog's `edit.paste` and then
// what is on the pasteboard (HaloPasteboardState), worded "Paste: <why>".
import AppKit
import HaloModel
import SuiteUI
import SwiftUI

struct HaloEditMenu: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform
    @FocusedValue(\.haloCopyPaste) private var clipboard
    @FocusedValue(\.timelineSelectAll) private var timelineSelectAll

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            target.item(.undo, shortcut: KeyboardShortcut("z"))
            target.item(.redo, shortcut: KeyboardShortcut("z", modifiers: [.command, .shift]))
        }
        CommandGroup(replacing: .pasteboard) {
            HaloPasteboardMenu(
                model: model, clipboard: clipboard, pasteboard: .shared, keys: timelineSelectAll == nil ? nil : target)
        }
    }
}

/// Edit's pasteboard group, a view so it re-reads HaloPasteboardState as the pasteboard and focus change.
struct HaloPasteboardMenu: View {
    let model: HaloProject?; let clipboard: HaloCopyPasteAction?; let pasteboard: HaloPasteboardState
    /// Where ⌘A sends Select All Keys while the timeline strip has focus; nil otherwise.
    var keys: HaloMenuTarget? = nil
    private var state: HaloEditMenuSpecs {
        HaloEditMenuSpecs(menu: HaloMenuState(project: clipboard == nil ? nil : model), pasteRefusal: pasteboard.pasteRefusal)
    }
    var body: some View {
        let state = state
        MenuCommand(HaloEditMenuSpecs.textOnly("edit.cut", title: "Cut"), on: state, systemImage: "scissors",
            shortcut: KeyboardShortcut("x")) {}.givingWay(to: .cut)
        MenuCommand(HaloEditMenuSpecs.textOnly("edit.copy", title: "Copy"), on: state, systemImage: "document.on.document",
            shortcut: KeyboardShortcut("c")) {}.givingWay(to: .copy)
        MenuCommand(HaloEditMenuSpecs.copyFrame, on: state, systemImage: "photo",
            shortcut: KeyboardShortcut("c", modifiers: [.command, .option])) { clipboard?(.copyFrame) }
        MenuCommand(HaloEditMenuSpecs.paste, on: state, systemImage: "document.on.clipboard",
            shortcut: KeyboardShortcut("v")) { clipboard?(.paste) }.givingWay(to: .paste)
        if let keys {
            keys.item(.selectAllKeys, systemImage: "checkmark.circle", shortcut: KeyboardShortcut("a"))
                .givingWay(to: .selectAll)
        } else {
            MenuCommand(HaloEditMenuSpecs.textOnly("edit.select-all", title: "Select All"), on: state,
                systemImage: "checkmark.circle", shortcut: KeyboardShortcut("a")) {}.givingWay(to: .selectAll)
        }
    }
}
