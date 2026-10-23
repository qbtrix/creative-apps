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
// edit first. The editor draws at `textEditScale`, the canvas zoom with no
// floor, so it draws at the committed size and the text doesn't jump on commit
// (#268). A commit with the app's measured extent fits the box in the same
// step (canvas-basics CB-5): an auto-width box takes both sides, a fixed-width
// one only the height, each rounded up to a whole point, at least 1. A text
// style change fits the same way: the app measures each selected text in its new
// style and `fitTextStyle` lands the fit in the "Change Text Style" step, so a
// wider font or weight never clips the text (#3339). Linux-safe.

/// A text's measured size in points, as the app lays it out.
public struct DesignTextExtent: Sendable, Hashable {
    public var width, height: Double

    public init(width: Double, height: Double) {
        (self.width, self.height) = (width, height)
    }
}

/// A text node placed by a Text click and the document before that click.
struct DesignPlacedText: Sendable, Equatable {
    var id: String
    var before: DesignSnapshot
}

extension DesignWorkspace {
    /// Starts editing a text node, selecting it. Refused for an unknown or non-text node, and
    /// for one that is locked or inside a locked group (#535).
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
    public mutating func commitTextEdit() { commitTextEdit(extent: nil) }

    /// Ends the edit as `commitTextEdit()`; with `extent`, the box fits it in the same step. A nil
    /// or non-finite extent keeps the frame. An existing node records "Edit Text" when its text or
    /// its fitted frame changed.
    public mutating func commitTextEdit(extent: DesignTextExtent?) {
        guard let id = editingTextID else { return }
        let (draft, placed) = (textDraft, placedText)
        (editingTextID, textDraft, placedText) = (nil, "", nil)
        let isBlank = draft.allSatisfy(\.isWhitespace)
        let edit: (inout DesignNode) -> Void = { node in
            node.text = draft
            node.frame = Self.fitted(node.frame, node.textStyle, extent)
        }
        if let placed {
            guard !isBlank else { return rewind(to: placed.before) }
            _ = pages.update(id, edit)
            record("Add Text", before: placed.before)
        } else if !isBlank, !isLockedInTree(id), var node = findNode(id) {
            let original = node
            edit(&node)
            guard node != original else { return }
            let before = snapshot
            _ = pages.update(id, edit)
            record("Edit Text", before: before)
        }
    }

    /// Fits each selected, unlocked text layer's box to `extents` (measured in its new style) inside
    /// the "Change Text Style" step the style change just made, as `commitTextEdit(extent:)` fits.
    /// A layer with no extent, an unselected or non-text one keeps its box; a fit that changes
    /// nothing records nothing.
    public mutating func fitTextStyle(_ extents: [String: DesignTextExtent]) {
        guard editingTextID == nil else { return }
        let before = snapshot
        for id in selectedNodeIDs where !isLockedInTree(id) {
            guard let extent = extents[id] else { continue }
            _ = pages.update(id) { node in
                if node.kind == .text { node.frame = Self.fitted(node.frame, node.textStyle, extent) }
            }
        }
        record("Change Text Style", before: before, coalescing: DesignEdit.runKey("text-style", selectedNodeIDs))
    }

    /// `frame` fitted to `extent`: both sides for an auto-width box, the height for a fixed-width
    /// one, each rounded up to a whole point and at least 1. Unchanged for a nil or non-finite extent.
    static func fitted(_ frame: DesignRect, _ style: DesignTextStyle, _ extent: DesignTextExtent?) -> DesignRect {
        guard let extent, extent.width.isFinite, extent.height.isFinite else { return frame }
        var fit = frame
        let fixed = style.fixedWidth == true
        fit.width = fixed ? frame.width : Swift.max(1, extent.width.rounded(.up))
        fit.height = Swift.max(1, extent.height.rounded(.up))
        return fit
    }

    /// Ends the edit and drops its draft; a node placed by the click is removed.
    public mutating func cancelTextEdit() {
        guard editingTextID != nil else { return }
        let placed = placedText
        (editingTextID, textDraft, placedText) = (nil, "", nil)
        if let placed { rewind(to: placed.before) }
    }

    /// Sets a text node's text as the step "Edit Text". Refused for an unknown, non-text or
    /// locked node (its own lock or a group's), and for empty or whitespace text.
    public mutating func setText(_ id: String, _ text: String) throws(DesignTreeError) {
        _ = try textNode(id)
        guard !text.allSatisfy(\.isWhitespace) else { throw .emptyText }
        try editNode(id, named: "Edit Text") { $0.text = text }
    }

    /// Screen points per document point for the inline editor at canvas `zoom`: the zoom itself,
    /// with no floor, so the editor draws the text at the size it commits at and nothing jumps
    /// on commit (#268). A zoom that isn't a positive finite number counts as 1.
    public static func textEditScale(zoom: Double) -> Double {
        zoom.isFinite && zoom > 0 ? zoom : 1
    }

    private func textNode(_ id: String) throws(DesignTreeError) -> DesignNode {
        guard let node = findNode(id) else { throw .unknownID(id) }
        guard node.kind == .text else { throw .notText(id) }
        guard !isLockedInTree(id) else { throw .locked(id) }
        return node
    }
}
