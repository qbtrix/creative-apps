// HaloCompositionCommands.swift: Halo's Composition menu in the menu bar: New
// Composition… (opens the sheet), Duplicate and Delete for the focused
// window's selected composition. The window publishes its actions as a
// focused scene value; a nil action disables its item rather than hiding it.
// Command-Delete while a text field has focus (renaming a composition in the
// sidebar) edits the text, as it does in any field, and never deletes the
// composition: HaloProject.compositionDeleteCommand decides.
import AppKit
import SwiftUI

extension FocusedValues {
    /// The focused window's composition actions; nil with no Halo window.
    @Entry var haloCompositionActions: HaloCompositionActions?
}

/// What the Composition menu calls. `duplicate` is nil with no composition
/// selected; `delete` is nil then too, and when only one composition is left.
/// `delete` gets whether a text field has keyboard focus.
struct HaloCompositionActions {
    var new: @MainActor () -> Void
    var duplicate: (@MainActor () -> Void)?
    var delete: (@MainActor (_ editingText: Bool) -> Void)?
}

/// The key window's text focus, read when a menu command fires.
enum HaloTextFocus {
    /// Whether an editable text view (a text field's editor) has keyboard focus.
    @MainActor static var isEditing: Bool {
        (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true
    }

    /// Gives Command-Delete back to the focused text field: delete to the
    /// start of the line, its standard behavior.
    @MainActor static func deleteToStartOfLine() {
        _ = NSApp.sendAction(#selector(NSStandardKeyBindingResponding.deleteToBeginningOfLine(_:)), to: nil, from: nil)
    }
}

struct HaloCompositionCommands: Commands {
    @FocusedValue(\.haloCompositionActions) private var actions

    var body: some Commands {
        CommandMenu("Composition") {
            Button("New Composition…", systemImage: "plus") { actions?.new() }
                .keyboardShortcut("n", modifiers: [.command, .option])
                .disabled(actions == nil)
            Button("Duplicate", systemImage: "plus.square.on.square") { actions?.duplicate?() }
                .keyboardShortcut("d")
                .disabled(actions?.duplicate == nil)
            Button("Delete", systemImage: "trash") { actions?.delete?(HaloTextFocus.isEditing) }
                .keyboardShortcut(.delete)
                .disabled(actions?.delete == nil)
        }
    }
}
