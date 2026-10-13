// DesignText.swift: the inline text edit. `editingTextID` names the text node
// being edited and `textDraft` is its live text; the canvas shows an editor over
// the node and sends the draft here. Nothing in the document changes until the
// edit commits.
//
// A node placed by a Text click is added when the click lands but is only kept
// by a commit: a non-empty draft records ONE step, "Add Text"; an empty or
// whitespace draft, or a cancel, removes it, puts back the selection from before
// the click and records nothing. An existing node's commit records "Edit Text"
// only for a changed, non-empty draft. Undo and redo wait while editing, and so
// do nudge and delete; anything that moves the selection or the tool commits the
// edit first. Linux-safe.

/// A text node placed by a Text click and the document before that click.
struct DesignPlacedText: Sendable, Equatable {
    var id: String
    var before: DesignSnapshot
}

extension DesignWorkspace {
    /// Starts editing a text node, selecting it. Refused for an unknown, non-text or locked node.
    public mutating func beginTextEdit(_ id: String) throws(DesignTreeError) {
        let node = try textNode(id)
        if editingTextID == id { return }
        commitTextEdit()
        selectItem(id)
        (editingTextID, textDraft) = (id, node.text)
    }

    /// Sets the edit's live text. Ignored when no edit is open.
    public mutating func setTextDraft(_ text: String) {
        if editingTextID != nil { textDraft = text }
    }

    /// Ends the edit and keeps its draft (see the file header for what is recorded).
    public mutating func commitTextEdit() {
        guard let id = editingTextID else { return }
        let (draft, placed) = (textDraft, placedText)
        (editingTextID, textDraft, placedText) = (nil, "", nil)
        let isBlank = draft.allSatisfy(\.isWhitespace)
        if let placed {
            guard !isBlank else { return rewind(to: placed.before) }
            _ = pages.update(id) { $0.text = draft }
            record("Add Text", before: placed.before)
        } else if !isBlank, let node = findNode(id), !node.isLocked, node.text != draft {
            let before = snapshot
            _ = pages.update(id) { $0.text = draft }
            record("Edit Text", before: before)
        }
    }

    /// Ends the edit and drops its draft; a node placed by the click is removed.
    public mutating func cancelTextEdit() {
        guard editingTextID != nil else { return }
        let placed = placedText
        (editingTextID, textDraft, placedText) = (nil, "", nil)
        if let placed { rewind(to: placed.before) }
    }

    /// Sets a text node's text as the step "Edit Text". Refused for an unknown, non-text or
    /// locked node, and for empty or whitespace text.
    public mutating func setText(_ id: String, _ text: String) throws(DesignTreeError) {
        _ = try textNode(id)
        guard !text.allSatisfy(\.isWhitespace) else { throw .emptyText }
        try editNode(id, named: "Edit Text") { $0.text = text }
    }

    private func textNode(_ id: String) throws(DesignTreeError) -> DesignNode {
        guard let node = findNode(id) else { throw .unknownID(id) }
        guard node.kind == .text else { throw .notText(id) }
        guard !node.isLocked else { throw .locked(id) }
        return node
    }
}
