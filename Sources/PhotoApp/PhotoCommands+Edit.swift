// PhotoCommands+Edit.swift: Photo's Edit menu items: Undo and Redo named for
// the edit; Cut, Copy, Paste and Select All in place of the system's
// pasteboard group; then Delete Selection and Fill Selection. Every item
// carries the system's SF Symbol for its action (PhotoEditItem), as the Layer
// menu's do. Cut, Copy and Paste act on the image only when no text has focus
// (photo-edit's decision): while the key window's first responder is a text
// view (a sheet's field, an inspector number, the layer name) or a sheet is
// up, they send the system's cut:, copy: and paste: instead, so Command-C
// copies the field's text. PhotoTextFocus watches the first responder so the
// items re-enable as a field takes focus. With no text focused, Cut and Copy
// are off with no image, Paste with no image on the pasteboard, and all three
// with no Photo window; each says why as its help. Select > All keeps
// Command-A (PhotoCommands+Select.swift), so Edit > Select All has no
// shortcut and runs the same text-first PhotoMenu.selectAll.
import AppKit
import SwiftUI

extension PhotoCommands {
    @CommandsBuilder var editMenu: some Commands {
        CommandGroup(replacing: .undoRedo) {
            PhotoUndoMenu(menu: menu)
        }
        CommandGroup(replacing: .pasteboard) {
            PhotoPasteboardMenu(menu: menu)
        }
        CommandGroup(after: .pasteboard) {
            PhotoSelectionEditMenu(menu: menu)
        }
    }
}

/// The Edit menu's items in order, with the system's symbol for each.
enum PhotoEditItem: CaseIterable {
    case undo, redo, cut, copy, paste, selectAll, deleteSelection, fillSelection

    /// The replacement pasteboard group, in the standard order.
    static let pasteboardGroup: [Self] = [.cut, .copy, .paste, .selectAll]

    var systemImage: String {
        switch self {
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        case .cut: "scissors"
        case .copy: "document.on.document"
        case .paste: "document.on.clipboard"
        case .selectAll: "checkmark.circle"
        case .deleteSelection: "trash"
        case .fillSelection: "paintbrush"
        }
    }
}

/// Whether the key window's first responder is a text view, kept current
/// from every window update so the Edit menu re-evaluates as focus moves.
@MainActor @Observable final class PhotoTextFocus {
    static let shared = PhotoTextFocus()
    private(set) var isEditingText = false
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    private init() {
        observer = NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { PhotoTextFocus.shared.refresh() }
        }
    }

    private func refresh() {
        let now = NSApp.keyWindow?.firstResponder is NSTextView
        if now != isEditingText { isEditingText = now }
    }
}

/// Undo and Redo, named for the edit.
struct PhotoUndoMenu: View {
    let menu: PhotoMenu

    var body: some View {
        Button(menu.undoTitle, systemImage: PhotoEditItem.undo.systemImage) { menu.perform(.undo) }
            .keyboardShortcut("z").disabled(!menu.canUndo)
        Button(menu.redoTitle, systemImage: PhotoEditItem.redo.systemImage) { menu.perform(.redo) }
            .keyboardShortcut("z", modifiers: [.command, .shift]).disabled(!menu.canRedo)
    }
}

/// Cut, Copy, Paste and Select All, a view so it can read the focused window's pasteboard state.
struct PhotoPasteboardMenu: View {
    let menu: PhotoMenu
    @FocusedValue(\.photoPasteboard) private var pasteboard

    var body: some View {
        let textFocused = PhotoTextFocus.shared.isEditingText
        ForEach(PhotoEditItem.pasteboardGroup, id: \.self) { item in
            switch item {
            case .cut: edit("Cut", .cut, item, key: "x", textFocused: textFocused)
            case .copy: edit("Copy", .copy, item, key: "c", textFocused: textFocused)
            case .paste: edit("Paste", .paste, item, key: "v", textFocused: textFocused)
            default:
                Button("Select All", systemImage: item.systemImage) { menu.selectAll() }
                    .disabled(!menu.canSelectAll && !textFocused)
            }
        }
    }

    private func edit(
        _ title: String, _ intent: EditIntent, _ item: PhotoEditItem, key: KeyEquivalent, textFocused: Bool
    ) -> some View {
        let held = pasteboard ?? PhotoPasteboardState()
        return Button(title, systemImage: item.systemImage) { menu.edit(intent) }
            .keyboardShortcut(key)
            .disabled(menu.isEditDisabled(intent, pasteboard: held, textHasFocus: textFocused))
            .help(menu.editHelp(intent, pasteboard: held).map { "\(title): \($0)" } ?? title)
    }
}

/// Delete Selection and Fill Selection.
struct PhotoSelectionEditMenu: View {
    let menu: PhotoMenu

    var body: some View {
        Divider()
        Button("Delete Selection", systemImage: PhotoEditItem.deleteSelection.systemImage) {
            menu.perform(.deleteSelection)
        }
        .disabled(!menu.canEditSelection)
        Button("Fill Selection", systemImage: PhotoEditItem.fillSelection.systemImage) {
            menu.perform(.fillSelection)
        }
        .disabled(!menu.canEditSelection)
    }
}

extension PhotoMenu {
    /// Paste's reason when the pasteboard holds something, just not an image.
    static let pasteHelpNoImage = "The pasteboard has no image."

    /// Why Cut, Copy or Paste can't act on the image, or nil.
    func editHelp(_ intent: EditIntent, pasteboard: PhotoPasteboardState) -> String? {
        switch intent {
        case .cut: cutHelp
        case .copy: copyHelp
        case .paste:
            if pasteboard.hasImage {
                pasteHelpWithImage
            } else {
                pasteboard.isEmpty ? pasteHelpWithoutImage : Self.pasteHelpNoImage
            }
        case .duplicateLayer: duplicateLayerHelp
        case .mergeDown: mergeDownHelp
        case .flattenImage: flattenHelp
        }
    }

    /// On while text has focus or a sheet is up, so the field gets the key.
    /// Otherwise off with no Photo window; in a window, Cut and Copy with no
    /// image, Paste with no image on the pasteboard.
    func isEditDisabled(_ intent: EditIntent, pasteboard: PhotoPasteboardState, textHasFocus: Bool = false) -> Bool {
        if textHasFocus || isPresenting { return false }
        guard hasWindow else { return true }
        switch intent {
        case .cut, .copy: return !hasImage
        case .paste: return !pasteboard.hasImage
        case .duplicateLayer, .mergeDown, .flattenImage: return editHelp(intent, pasteboard: pasteboard) != nil
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
        // Layer commands have no text counterpart; the Layer menu sends them straight to the window.
        case .duplicateLayer: #selector(PhotoLayerActions.duplicateLayer(_:))
        case .mergeDown: #selector(PhotoLayerActions.mergeDown(_:))
        case .flattenImage: #selector(PhotoLayerActions.flattenImage(_:))
        }
    }
}
