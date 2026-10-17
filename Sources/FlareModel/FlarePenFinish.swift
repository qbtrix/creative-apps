// FlarePenFinish.swift: Return on the stage ends an open pen path (packet draw-key-save, DK-9). `finishPath` commits
// the pen draft as it stands, an open path, as one "Add Path" undo step, the way a click on its first anchor commits a
// closed one (FlareDrag.swift). A draft with fewer than `minimumFinishAnchors` anchors is refused: nothing changes, no
// undo step, and the draft stays so the path can carry on. No pen draft is a no-op.
import FlareCore

extension FlareWorkspace {
    /// The fewest anchors an open pen path finishes with: one anchor draws no segment.
    public static let minimumFinishAnchors = 2

    /// Why Finish Path can't act now, as its reason; nil while an open pen draft has enough anchors to finish.
    public var finishPathHelp: String? {
        guard let draft, draft.tool == .pen, !draft.isClosed else { return "Click with the Pen to start a path." }
        guard draft.anchors.count >= Self.minimumFinishAnchors else { return "Click a second point to finish the path." }
        return lockedHelp(.pen)
    }

    /// Commits the open pen draft as a new "Path N" layer above the selected one, in one "Add Path" undo step, and
    /// selects it. Fewer than `minimumFinishAnchors` anchors, or a closed or non-pen draft, changes nothing; a refused
    /// commit (a locked layer, a path too small to see) keeps the draft and says why.
    public mutating func finishPath() {
        guard let pending = draft, pending.tool == .pen, !pending.isClosed,
              pending.anchors.count >= Self.minimumFinishAnchors else { return }
        if let reason = lockedHelp(.pen) { return refuse(.refused(reason)) }
        cancelDrag()
        commit(pending)
        if layerError != nil { draft = pending }
    }
}
