// PhotoCommands+Edit.swift: Photo's Edit menu items: Undo and Redo named for
// the edit; Cut, Copy and Paste in place of the system's pasteboard group; then
// Delete Selection and Fill Selection. Cut, Copy and Paste act on the image
// only when no text has focus (photo-edit's decision): while the key window's
// first responder is a text view (a sheet's field, an inspector number, the
// layer name) or a sheet is up, they send the system's cut:, copy: and paste:
// instead, so Command-C copies the field's text. A disabled item would
// swallow its key, so Cut and Copy are off only in a focused window with no
// image, and Paste only with an empty pasteboard; each says why as its help.
// Select > All keeps Command-A (PhotoCommands+Select.swift).
import AppKit
import SwiftUI

extension PhotoCommands {
    @CommandsBuilder var editMenu: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(menu.undoTitle) { menu.perform(.undo) }.keyboardShortcut("z").disabled(!menu.canUndo)
            Button(menu.redoTitle) { menu.perform(.redo) }.keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!menu.canRedo)
        }
        CommandGroup(replacing: .pasteboard) {
            PhotoPasteboardMenu(menu: menu)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Delete Selection") { menu.perform(.deleteSelection) }.disabled(!menu.canEditSelection)
            Button("Fill Selection") { menu.perform(.fillSelection) }.disabled(!menu.canEditSelection)
        }
    }
}

/// Cut, Copy and Paste, a view so it can read the focused window's pasteboard state.
struct PhotoPasteboardMenu: View {
    let menu: PhotoMenu
    @FocusedValue(\.photoPasteboard) private var pasteboard

    var body: some View {
        item("Cut", .cut, key: "x")
        item("Copy", .copy, key: "c")
        item("Paste", .paste, key: "v")
    }

    private func item(_ title: String, _ intent: EditIntent, key: KeyEquivalent) -> some View {
        let held = pasteboard ?? PhotoPasteboardState()
        return Button(title) { menu.edit(intent) }
            .keyboardShortcut(key)
            .disabled(menu.isEditDisabled(intent, pasteboard: held))
            .help(menu.editHelp(intent, pasteboard: held).map { "\(title): \($0)" } ?? title)
    }
}

extension PhotoMenu {
    /// Why Cut, Copy or Paste can't act on the image, or nil.
    func editHelp(_ intent: EditIntent, pasteboard: PhotoPasteboardState) -> String? {
        switch intent {
        case .cut: cutHelp
        case .copy: copyHelp
        case .paste: pasteboard.hasImage ? pasteHelpWithImage : pasteHelpWithoutImage
        }
    }

    /// Off only when no text could want the key either: in a focused window
    /// with no sheet up, Cut and Copy with no image, Paste with nothing on
    /// the pasteboard.
    func isEditDisabled(_ intent: EditIntent, pasteboard: PhotoPasteboardState) -> Bool {
        guard hasWindow, !isPresenting else { return false }
        switch intent {
        case .cut, .copy: return !hasImage
        case .paste: return pasteboard.isEmpty
        }
    }

    /// The menu item's action, on the key window's focused text if any.
    @MainActor func edit(_ intent: EditIntent) {
        edit(intent, focusedText: NSApp.keyWindow?.firstResponder as? NSTextView)
    }

    /// The focused text's own command while text has focus, else the image's
    /// in a window with no sheet up, else the system's down the responder chain.
    @MainActor func edit(_ intent: EditIntent, focusedText: NSResponder?) {
        let action = Self.textAction(intent)
        if let focusedText {
            _ = focusedText.tryToPerform(action, with: nil)
        } else if hasWindow && !isPresenting {
            perform(.edit(intent))
        } else {
            _ = NSApplication.shared.sendAction(action, to: nil, from: nil)
        }
    }

    /// The system's text command for an edit.
    static func textAction(_ intent: EditIntent) -> Selector {
        switch intent {
        case .cut: #selector(NSText.cut(_:))
        case .copy: #selector(NSText.copy(_:))
        case .paste: #selector(NSText.paste(_:))
        }
    }
}
