// HaloCompositionCommands.swift: Halo's Composition menu in the menu bar: New
// ⌥⌘N (opens the New Composition sheet), Duplicate ⌘D and Delete ⌘⌫ for the
// focused window's selected composition, each sent through `haloPerform` and
// disabled with the Model's reason as help (SuiteUI's MenuCommand). Command-Delete
// while a text field has focus (renaming a composition in the sidebar) edits
// the text, as it does in any field, and never deletes the composition: the
// window's route asks HaloProject.compositionDeleteCommand with HaloTextFocus.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI

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
    @FocusedValue(\.haloProject) private var model
    @FocusedValue(\.haloPerform) private var perform

    private var target: HaloMenuTarget { HaloMenuTarget(model: model, perform: perform) }

    var body: some Commands {
        CommandMenu("Composition") {
            MenuCommand(
                command: .newComposition, target: target, title: "New", systemImage: "plus",
                shortcut: KeyboardShortcut("n", modifiers: [.command, .option]))
            MenuCommand(
                command: .duplicateComposition, target: target, systemImage: "plus.square.on.square",
                shortcut: KeyboardShortcut("d"))
            MenuCommand(
                command: .deleteComposition, target: target, systemImage: "trash", shortcut: KeyboardShortcut(.delete))
        }
    }
}
