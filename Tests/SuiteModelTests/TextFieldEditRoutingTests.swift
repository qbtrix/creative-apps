// TextFieldEditRoutingTests.swift (editor-menus, #4830): a focused text field
// keeps its standard edit keys in every editor. While a text field (its field
// editor) or an editable text view has focus, Cut, Copy, Paste, Select All,
// Undo, Redo and Delete stay on and send the field's own action, even when the
// app's item is off; otherwise the item is the app's, as the app leaves it.
import SuiteModel
import Testing

struct TextFieldEditRoutingTests {
    static let fieldEditor = TextFocus(isText: true, isEditable: true, isFieldEditor: true)
    static let readOnlyFieldEditor = TextFocus(isText: true, isEditable: false, isFieldEditor: true)
    static let textView = TextFocus(isText: true, isEditable: true, isFieldEditor: false)
    static let readOnlyText = TextFocus(isText: true, isEditable: false, isFieldEditor: false)

    @Test func eachCommandSendsTheFieldsOwnAction() {
        let actions = TextEditCommand.allCases.map(\.responderAction)
        #expect(actions == ["cut:", "copy:", "paste:", "selectAll:", "undo:", "redo:", "deleteBackward:"])
    }

    /// #4605: ⌘A in FILL's hex field selects its text, not every layer.
    @Test(arguments: TextEditCommand.allCases) func aFocusedFieldTakesTheItem(_ command: TextEditCommand) {
        let item = TextFieldEditRouting.item(command, focus: Self.fieldEditor, appEnabled: true, appHelp: "Selects every layer.")
        #expect(item.route == .field(action: command.responderAction))
        #expect(item.isEnabled)
        #expect(item.help == command.fieldHelp)
    }

    /// The app's item is off (nothing selected to copy), yet the field's text can still be copied.
    @Test(arguments: TextEditCommand.allCases) func aFocusedFieldTurnsAnOffItemOn(_ command: TextEditCommand) {
        let item = TextFieldEditRouting.item(command, focus: Self.textView, appEnabled: false, appHelp: "Copy: Nothing is selected.")
        #expect(item == TextEditItem(route: .field(action: command.responderAction), isEnabled: true, help: command.fieldHelp))
    }

    /// A selectable text field's field editor isn't editable, but it still takes Copy and Select All.
    @Test func aFieldEditorCountsEvenWhenReadOnly() {
        #expect(Self.readOnlyFieldEditor.takesEditKeys)
        let item = TextFieldEditRouting.item(.copy, focus: Self.readOnlyFieldEditor, appEnabled: false, appHelp: "Off.")
        #expect(item.route == .field(action: "copy:"))
    }

    /// With the canvas focused, or read-only text that isn't a field, the item is the app's, on or off as the app says.
    @Test(arguments: [TextFocus.none, readOnlyText, TextFocus(isText: false, isEditable: true, isFieldEditor: true)])
    func otherwiseTheItemIsTheApps(_ focus: TextFocus) {
        #expect(!focus.takesEditKeys)
        let on = TextFieldEditRouting.item(.selectAll, focus: focus, appEnabled: true, appHelp: "Selects every layer.")
        #expect(on == TextEditItem(route: .app, isEnabled: true, help: "Selects every layer."))
        let off = TextFieldEditRouting.item(.paste, focus: focus, appEnabled: false, appHelp: "Paste: The pasteboard is empty.")
        #expect(off == TextEditItem(route: .app, isEnabled: false, help: "Paste: The pasteboard is empty."))
    }
}
