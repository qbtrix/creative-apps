// HaloEditMenu.swift: Halo's Undo ⌘Z and Redo ⇧⌘Z in place of the system
// pair, titled for the step they act on by `HaloProject.title(for:)` ("Undo
// New Layer"), sent through the focused window and disabled with the Model's
// reason as help (HaloMenuTarget.item, from the catalog spec). The pasteboard
// group is Halo's own (clipboard-interop CB-10), so there is one Paste: Cut ⌘X,
// Copy ⌘C, Copy Frame ⌥⌘C, Paste ⌘V and Select All ⌘A. While a text field has
// focus, Cut, Copy, Paste and Select All send the system's cut:, copy:, paste:
// and selectAll: to it, so fields edit as anywhere. Otherwise Cut, Copy and
// Select All are off with a reason (Halo copies frames, not layers, yet), Copy
// Frame follows the catalog's `edit.copy-frame`, and Paste the catalog's
// `edit.paste` and then what is on the pasteboard (HaloPasteboardState),
// worded "Paste: <why>".
import AppKit
import HaloModel
import SuiteUI
import SwiftUI

struct HaloEditMenu: Commands {
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform
    @FocusedValue(\.haloClipboard) private var clipboard

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            target.item(.undo, shortcut: KeyboardShortcut("z"))
            target.item(.redo, shortcut: KeyboardShortcut("z", modifiers: [.command, .shift]))
        }
        CommandGroup(replacing: .pasteboard) {
            HaloPasteboardMenu(model: model, clipboard: clipboard, pasteboard: .shared)
        }
    }
}

/// Edit's pasteboard group, a view so it re-reads HaloPasteboardState as the pasteboard and focus change.
struct HaloPasteboardMenu: View {
    let model: HaloProject?
    let clipboard: HaloClipboardAction?
    let pasteboard: HaloPasteboardState

    static let textOnly = "works on text in a field; Halo copies frames, not layers, yet."

    private var state: HaloMenuState { HaloMenuState(project: clipboard == nil ? nil : model) }

    var body: some View {
        text("Cut", "scissors", "x", #selector(NSText.cut(_:)))
        text("Copy", "document.on.document", "c", #selector(NSText.copy(_:)))
        MenuCommand(
            HaloMenuState.spec("edit.copy-frame"), on: state, title: "Copy Frame", systemImage: "photo",
            shortcut: KeyboardShortcut("c", modifiers: [.command, .option])
        ) { clipboard?(.copyFrame) }
        paste
        text("Select All", "checkmark.circle", "a", #selector(NSText.selectAll(_:)))
    }

    /// Paste into the focused field, else the catalog's reason, then the pasteboard's.
    @ViewBuilder private var paste: some View {
        let key = KeyboardShortcut("v")
        if pasteboard.isEditingText {
            MenuCommand("Paste", systemImage: "document.on.clipboard", shortcut: key, help: "Pastes into the text field.") {
                _ = NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            }
        } else if let why = pasteboard.pasteRefusal, state.availability("edit.paste").why == nil {
            MenuCommand("Paste", systemImage: "document.on.clipboard", shortcut: key, help: "Paste: \(why)", isEnabled: false) {}
        } else {
            MenuCommand(HaloMenuState.spec("edit.paste"), on: state, title: "Paste", systemImage: "document.on.clipboard",
                        shortcut: key) { clipboard?(.paste) }
        }
    }

    /// A text-field command: on while a field has focus, else off with the reason.
    private func text(_ title: String, _ image: String, _ key: KeyEquivalent, _ action: Selector) -> MenuCommand {
        let on = pasteboard.isEditingText
        return MenuCommand(
            title, systemImage: image, shortcut: KeyboardShortcut(key),
            help: on ? "\(title) in the text field." : "\(title) \(Self.textOnly)", isEnabled: on
        ) { _ = NSApp.sendAction(action, to: nil, from: nil) }
    }
}
