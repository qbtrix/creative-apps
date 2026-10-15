// LiveKeyframes+Frames.swift: the live frame inserts, frame removes and labels, and the `KeyframeEditing` conformance
// (docs/blueprints/flare/features/live-keys.md, task KY-7). A frame edit is FlareCore's `ShiftKeyframes(owner:)` per
// layer with a key at or after its frame. An insert that pushes a key or a label past a scene's last frame grows the
// scene with `SetSceneTiming` in the same "Insert Frame" step. A "Remove Frame" drops the keys inside the removed run
// with `RemoveKeyframe(owner:)` and shifts the rest back. An edit on every layer of a scene moves the scene ruler, so
// its labels at or after the frame move by the same count and a label inside a removed run goes. A symbol has no scene:
// its frame edits never grow anything and move no labels. A label names one frame: naming a frame replaces the label
// already there, and a nil name removes it. Agrees with `FakeKeyframes` on scenes.
import FlareCore

extension LiveKeyframes: KeyframeEditing {}

extension LiveKeyframes {
    public func insertFrames(_ count: Int, at frame: Int, layerIDs: [String], owner: LayerOwner,
                             in engine: inout CommandEngine) throws {
        let edit = try FrameEdit(at: frame, layerIDs: layerIDs, owner: owner, in: engine.document)
        guard count > 0 else { return }
        var shifts: [ShiftKeyframes] = []
        var length = 0  // the scene length the shifted keys and labels need
        for layer in edit.layers {
            guard let last = Self.lastKey(of: layer), last >= frame else { continue }
            let (to, overflow) = last.addingReportingOverflow(count)
            guard !overflow, to < Int.max else { throw CommandError.invalidFrame(count) }
            shifts.append(ShiftKeyframes(owner: owner, layerID: layer.id, fromFrame: frame, toFrame: last, delta: count))
            length = max(length, to + 1)
        }
        var moved: [String: Int] = [:]
        for (name, at) in edit.labels where at >= frame {
            let (to, overflow) = at.addingReportingOverflow(count)
            guard !overflow else { throw CommandError.invalidFrame(count) }
            moved[name] = to
            length = max(length, to)  // a label may sit on the frame just past the last one
        }
        try engine.group("Insert Frame") { engine in
            for shift in shifts { try engine.perform(shift) }
            if let scene = edit.scene, length > scene.durationFrames {
                try engine.perform(SetSceneTiming(sceneID: scene.id, fps: scene.fps, durationFrames: length))
            }
            try Self.place(moved, in: edit.scene, engine: &engine)
        }
    }

    public func removeFrames(_ count: Int, at frame: Int, layerIDs: [String], owner: LayerOwner,
                             in engine: inout CommandEngine) throws {
        let edit = try FrameEdit(at: frame, layerIDs: layerIDs, owner: owner, in: engine.document)
        guard count > 0 else { return }
        let (sum, overflow) = frame.addingReportingOverflow(count)
        let end = overflow ? Int.max : sum  // the first frame after the removed run
        let run = frame..<end
        try engine.group("Remove Frame") { engine in
            for layer in edit.layers {
                for property in layer.tracks.keys.sorted() {
                    for key in layer.tracks[property] ?? [] where run.contains(key.frame) {
                        try engine.perform(RemoveKeyframe(owner: owner, layerID: layer.id, property: property, frame: key.frame))
                    }
                }
                guard let last = Self.lastKey(of: layer), last >= end else { continue }
                try engine.perform(ShiftKeyframes(owner: owner, layerID: layer.id, fromFrame: end, toFrame: last, delta: -count))
            }
            if let scene = edit.scene {
                for (name, at) in edit.labels.sorted(by: { $0.key < $1.key }) where run.contains(at) {
                    try engine.perform(RemoveFrameLabel(sceneID: scene.id, name: name))
                }
            }
            try Self.place(edit.labels.filter { $0.value >= end }.mapValues { $0 - count }, in: edit.scene, engine: &engine)
        }
    }

    public func setLabel(_ name: String?, at frame: Int, sceneID: String, in engine: inout CommandEngine) throws {
        guard let scene = engine.document.scenes.first(where: { $0.id == sceneID }) else { throw CommandError.sceneNotFound(sceneID) }
        guard frame >= 0 else { throw CommandError.invalidFrame(frame) }
        if name?.isEmpty == true { throw CommandError.invalidDocument("A label needs a name.") }
        // One label per frame: the label already on this frame goes, unless it is the one being set.
        let replaced = scene.labels.filter { $0.value == frame && $0.key != name }.keys.sorted()
        try engine.group(name == nil ? "Remove Frame Label" : "Set Frame Label") { engine in
            for old in replaced { try engine.perform(RemoveFrameLabel(sceneID: sceneID, name: old)) }
            if let name { try engine.perform(SetFrameLabel(sceneID: sceneID, name: name, frame: frame)) }
        }
    }

    /// What a frame insert or remove works on: the named layers in the owner's order, the owner's scene (nil for a
    /// symbol), and the scene's labels when the edit covers every layer of it (empty otherwise).
    private struct FrameEdit {
        var layers: [Layer]
        var scene: FlareScene?
        var labels: [String: Int]

        /// Throws for a frame before 0, a missing scene, or a layer the owner doesn't hold.
        init(at frame: Int, layerIDs: [String], owner: LayerOwner, in document: Document) throws {
            guard frame >= 0 else { throw CommandError.invalidFrame(frame) }
            scene = nil
            if case .scene(let sceneID) = owner {
                guard let found = document.scenes.first(where: { $0.id == sceneID }) else {
                    throw CommandError.sceneNotFound(sceneID)
                }
                scene = found
            }
            let all = document.layers(of: owner) ?? []
            let held = Set(all.map(\.id))
            if let missing = layerIDs.first(where: { !held.contains($0) }) { throw CommandError.layerNotFound(missing) }
            let named = Set(layerIDs)
            layers = all.filter { named.contains($0.id) }
            labels = !all.isEmpty && held.isSubset(of: named) ? scene?.labels ?? [:] : [:]
        }
    }

    /// Sets each label to its new frame, in name order, inside the caller's step. Nothing for a symbol.
    private static func place(_ labels: [String: Int], in scene: FlareScene?, engine: inout CommandEngine) throws {
        guard let scene else { return }
        for (name, frame) in labels.sorted(by: { $0.key < $1.key }) {
            try engine.perform(SetFrameLabel(sceneID: scene.id, name: name, frame: frame))
        }
    }

    private static func lastKey(of layer: Layer) -> Int? {
        layer.tracks.values.compactMap { $0.map(\.frame).max() }.max()
    }
}
