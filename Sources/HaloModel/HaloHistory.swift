// HaloHistory.swift (HF-2, #208): Edit > Undo and Redo on the project. Each
// goes one whole-document step through `services.history`, replaces the
// document with W0's `restore` (no new step, refusal cleared, coalescing
// ended) and marks the file unsaved. Selection rides in the document, so a
// step brings it back exactly; selecting, scrubbing and playback never call
// `edit`, so they are never steps. Linux-safe: no UI imports.

extension HaloProject {
    /// Goes back one step; nothing when there is nothing to undo.
    public mutating func undo() {
        guard let back = services.history.undo(document, in: &history) else { return }
        restore(back)
        file.unsaved = true
    }

    /// Goes forward one undone step; nothing when there is nothing to redo.
    public mutating func redo() {
        guard let forward = services.history.redo(document, in: &history) else { return }
        restore(forward)
        file.unsaved = true
    }

    /// "Undo Delete Composition"; nil when there is nothing to undo.
    public var undoTitle: String? { history.undoTitle }

    /// "Redo New Layer"; nil when there is nothing to redo.
    public var redoTitle: String? { history.redoTitle }
}
