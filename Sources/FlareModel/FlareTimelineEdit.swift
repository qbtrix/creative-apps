// FlareTimelineEdit.swift: key selection, key moves and deletes, frames and labels on the workspace
// (inspector-timeline IT-3). Every edit goes through `services.keyframes` (FlareCore's key commands) as one undo step;
// a refusal changes nothing and says why in `timelineError`. A key drag sends one-frame (or larger) steps that merge
// into one "Move Keyframe" entry under a key holding `keyDragSerial`, so `endKeyDrag` starts the next drag's entry.
// Frame edits act on every layer of the edited owner at the playhead, so a scene's labels move with its keys.
// The key selection is a thin set of `KeyRef`s that follows the keys it names; the editor kernel takes it over later.
import FlareCore

extension FlareWorkspace {
    /// What a timeline edit says when no key is selected.
    public static let selectKeyFirst = "Select a keyframe first."

    /// Selects `key`, or toggles it into the selection when `extending`.
    public mutating func selectKey(_ key: KeyRef, extending: Bool) {
        timelineError = nil
        guard extending else { return selectedKeys = [key] }
        if let index = selectedKeys.firstIndex(of: key) {
            selectedKeys.remove(at: index)
        } else {
            selectedKeys.append(key)
        }
    }

    /// Moves the selected keys `frames` (the step since the last call) in the drag that began at `dragStart`; every
    /// step until `endKeyDrag()` merges into one "Move Keyframe" entry. A key landing on another refuses.
    public mutating func moveSelectedKeys(by frames: Int, dragStart: Int) {
        guard !selectedKeys.isEmpty else { return timelineError = Self.selectKeyFirst }
        guard frames != 0 else { return }
        let keys = Set(selectedKeys), keyframes = services.keyframes
        let coalesceKey = "keys-\(dragStart)-\(keyDragSerial)"
        guard timelineStep({ owner, engine in
            try keyframes.moveKeys(keys, by: frames, owner: owner, coalesceKey: coalesceKey, in: &engine)
        }) else { return }
        selectedKeys = selectedKeys.map { KeyRef(layerID: $0.layerID, property: $0.property, frame: $0.frame + frames) }
    }

    /// Ends the key drag under way, so the next move is a new undo entry.
    public mutating func endKeyDrag() { keyDragSerial &+= 1 }

    /// Deletes the selected keys as one "Delete Keyframe" entry.
    public mutating func removeSelectedKeys() {
        guard !selectedKeys.isEmpty else { return timelineError = Self.selectKeyFirst }
        let keys = Set(selectedKeys), keyframes = services.keyframes
        guard timelineStep({ owner, engine in try keyframes.removeKeys(keys, owner: owner, in: &engine) }) else { return }
        selectedKeys = []
    }

    /// Why Edit > Delete (the Delete key) can't act now: nil while keyframes are selected; deleting art waits for F18.
    public var deleteHelp: String? {
        selectedKeys.isEmpty ? "Select keyframes to delete; deleting art isn't built yet (F18)." : nil
    }

    /// Edit > Delete: removes the selected keyframes, one undo step; nothing while none are selected.
    public mutating func deleteSelection() {
        guard deleteHelp == nil else { return }
        removeSelectedKeys()
    }

    /// Inserts `count` frames at the playhead on every layer: later keys and labels move `count` later.
    public mutating func insertFrames(_ count: Int) {
        let frame = currentFrame, layerIDs = (ownerLayers ?? []).map(\.id), keyframes = services.keyframes
        guard timelineStep({ owner, engine in
            try keyframes.insertFrames(count, at: frame, layerIDs: layerIDs, owner: owner, in: &engine)
        }) else { return }
        selectedKeys = selectedKeys.map { key in
            key.frame < frame ? key : KeyRef(layerID: key.layerID, property: key.property, frame: key.frame + count)
        }
    }

    /// Removes `count` frames at the playhead on every layer: keys inside them go, later keys and labels move back.
    public mutating func removeFrames(_ count: Int) {
        let frame = currentFrame, layerIDs = (ownerLayers ?? []).map(\.id), keyframes = services.keyframes
        guard timelineStep({ owner, engine in
            try keyframes.removeFrames(count, at: frame, layerIDs: layerIDs, owner: owner, in: &engine)
        }) else { return }
        let end = frame.addingReportingOverflow(max(count, 0))
        selectedKeys = selectedKeys.compactMap { key in
            if key.frame < frame { return key }
            if end.overflow || key.frame < end.partialValue { return nil }
            return KeyRef(layerID: key.layerID, property: key.property, frame: key.frame - count)
        }
    }

    /// Sets the selected scene's label at the playhead; nil removes it.
    public mutating func setLabel(_ name: String?) {
        guard let sceneID = selectedSceneID else { return timelineError = FlareLayerError.noDocument.message }
        let frame = currentFrame, keyframes = services.keyframes
        timelineStep { _, engine in try keyframes.setLabel(name, at: frame, sceneID: sceneID, in: &engine) }
    }

    /// The selected scene's labels by frame; empty with no document or scene.
    public var timelineLabels: [Int: String] {
        guard let document, let id = selectedSceneID else { return [:] }
        let labels = services.keyframes.labels(document, sceneID: id)
        return Dictionary(labels.map { ($0.value, $0.key) }, uniquingKeysWith: { a, b in min(a, b) })
    }

    /// Runs `body` on the edited owner as one undo step. A refusal changes nothing, leaves `layerError` as it was and
    /// says why in `timelineError`; success clears it. True when the edit landed.
    @discardableResult
    private mutating func timelineStep(_ body: (LayerOwner, inout CommandEngine) throws -> Void) -> Bool {
        guard let owner = propertyOwner, engine != nil else {
            timelineError = FlareLayerError.noDocument.message
            return false
        }
        let layerErrorWas = layerError
        step { try body(owner, &$0) }
        guard let error = layerError else {
            timelineError = nil
            return true
        }
        timelineError = error.message
        layerError = layerErrorWas
        return false
    }
}
