// TextFieldEditRouting.swift (editor-menus, #4830): where an editor's Edit
// item goes while a text field has the keys. An app that replaces the
// system's pasteboard or undo group (Flare, Library) owns ⌘X, ⌘C, ⌘V, ⌘A, ⌘Z
// and ⇧⌘Z, so without this a focused hex or name field loses its standard
// edit keys to the canvas (#4605: ⌘A in FILL's hex field selected every
// layer). While an editable text field, or the window's field editor, is the
// key window's first responder, the item stays enabled whatever the app's
// own reason, and it sends the field's own responder action (cut:, copy:,
// paste:, selectAll:, undo:, redo:, deleteBackward:). Otherwise the item is
// the app's, enabled and helped as the app says. SuiteUI's
// MenuCommand.givingWay(to:) reads the first responder and acts on this.

/// An Edit menu command that a focused text field also answers.
public enum TextEditCommand: String, CaseIterable, Sendable {
    case cut, copy, paste, selectAll, undo, redo, delete

    /// The field's own responder action, as a selector name.
    public var responderAction: String {
        switch self {
        case .cut: "cut:"
        case .copy: "copy:"
        case .paste: "paste:"
        case .selectAll: "selectAll:"
        case .undo: "undo:"
        case .redo: "redo:"
        // Delete's key is Backspace: in a field it removes the selection, or the character before the caret.
        case .delete: "deleteBackward:"
        }
    }

    /// The item's help while it acts on the field.
    public var fieldHelp: String {
        switch self {
        case .cut: "Cuts the selected text in the field."
        case .copy: "Copies the selected text in the field."
        case .paste: "Pastes into the field."
        case .selectAll: "Selects all the text in the field."
        case .undo: "Undoes the last typing in the field."
        case .redo: "Redoes the last typing in the field."
        case .delete: "Deletes the selected text in the field."
        }
    }
}

/// What the key window's first responder is, as far as the Edit menu cares.
public struct TextFocus: Equatable, Sendable {
    /// The first responder is a text view (an NSText).
    public var isText: Bool
    /// That text view takes typing.
    public var isEditable: Bool
    /// That text view is the window's field editor, standing in for a text field.
    public var isFieldEditor: Bool

    public init(isText: Bool = false, isEditable: Bool = false, isFieldEditor: Bool = false) {
        self.isText = isText
        self.isEditable = isEditable
        self.isFieldEditor = isFieldEditor
    }

    /// Nothing textual has focus: the canvas, a list, or no window.
    public static let none = TextFocus()

    /// A text field (its field editor) or an editable text view has the keys.
    public var takesEditKeys: Bool { isText && (isEditable || isFieldEditor) }
}

/// Where an Edit item sends its action.
public enum TextEditRoute: Equatable, Sendable {
    /// To the focused field: this responder action, down the key window's responder chain.
    case field(action: String)
    /// To the app's own action.
    case app
}

/// One Edit item as the focus leaves it: where it goes, whether it is on, and its help.
public struct TextEditItem: Equatable, Sendable {
    public let route: TextEditRoute
    public let isEnabled: Bool
    public let help: String

    public init(route: TextEditRoute, isEnabled: Bool, help: String) {
        self.route = route
        self.isEnabled = isEnabled
        self.help = help
    }
}

public enum TextFieldEditRouting {
    /// `command`'s item given `focus`, where the app's own item is `appEnabled` with `appHelp`
    /// (its summary, or why it can't run).
    public static func item(_ command: TextEditCommand, focus: TextFocus, appEnabled: Bool, appHelp: String) -> TextEditItem {
        guard focus.takesEditKeys else {
            return TextEditItem(route: .app, isEnabled: appEnabled, help: appHelp)
        }
        return TextEditItem(route: .field(action: command.responderAction), isEnabled: true, help: command.fieldHelp)
    }
}
