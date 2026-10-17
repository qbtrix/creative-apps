// FlareTimelineEdit.swift: key selection, key moves and deletes, frames and labels on the workspace
// (inspector-timeline IT-3). IT-0 declares the signatures as stubs (lead.md rule 18): every edit changes nothing and
// says why in `timelineError`, `endKeyDrag` ends the drag, and the labels read `services.keyframes`. IT-3 fills the
// bodies in through `services.keyframes` without changing a signature.
import FlareCore

extension FlareWorkspace {
    /// What a timeline edit says until IT-3 lands.
    public static let timelineNotBuilt = "Keyframe editing isn't built yet."

    /// Selects `key`, or toggles it into the selection when `extending`. Stub (IT-0): changes nothing.
    public mutating func selectKey(_ key: KeyRef, extending: Bool) { timelineError = Self.timelineNotBuilt }

    /// Moves the selected keys `frames` from `dragStart`, one undo entry per drag. Stub (IT-0): changes nothing.
    public mutating func moveSelectedKeys(by frames: Int, dragStart: Int) { timelineError = Self.timelineNotBuilt }

    /// Ends the key drag under way, so the next move is a new undo entry.
    public mutating func endKeyDrag() { keyDragSerial &+= 1 }

    /// Deletes the selected keys as one entry. Stub (IT-0): changes nothing.
    public mutating func removeSelectedKeys() { timelineError = Self.timelineNotBuilt }

    /// Inserts `count` frames at the playhead. Stub (IT-0): changes nothing.
    public mutating func insertFrames(_ count: Int) { timelineError = Self.timelineNotBuilt }

    /// Removes `count` frames at the playhead. Stub (IT-0): changes nothing.
    public mutating func removeFrames(_ count: Int) { timelineError = Self.timelineNotBuilt }

    /// Sets the label at the playhead; nil removes it. Stub (IT-0): changes nothing.
    public mutating func setLabel(_ name: String?) { timelineError = Self.timelineNotBuilt }

    /// The selected scene's labels by frame; empty with no document or scene.
    public var timelineLabels: [Int: String] {
        guard let document, let id = selectedSceneID else { return [:] }
        let labels = services.keyframes.labels(document, sceneID: id)
        return Dictionary(labels.map { ($0.value, $0.key) }, uniquingKeysWith: { a, b in min(a, b) })
    }
}
