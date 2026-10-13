// CompositionDeleteCommand.swift: what Composition > Delete (Command-Delete)
// does at the moment it fires. While a text field has focus, as when a
// composition is being renamed in the sidebar, the key belongs to the field
// (delete to the start of the line) and never deletes the composition.

/// What Composition > Delete does when it fires.
public enum CompositionDeleteCommand: Sendable, Equatable {
    /// A text field has focus: the key edits its text; nothing is deleted.
    case editText
    /// Deletes the composition with this id.
    case delete(String)
    /// Nothing to delete: no composition selected, or only one left.
    case unavailable
}

extension HaloProject {
    /// What Composition > Delete does now. `editingText` is whether a text
    /// field (the sidebar's rename field or any other) has keyboard focus.
    public func compositionDeleteCommand(editingText: Bool) -> CompositionDeleteCommand {
        if editingText { return .editText }
        guard canDeleteComposition, let id = selectedComposition?.id else { return .unavailable }
        return .delete(id)
    }
}
