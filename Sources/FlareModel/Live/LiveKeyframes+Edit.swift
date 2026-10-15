// LiveKeyframes+Edit.swift: the live key moves and removes (docs/blueprints/flare/features/live-keys.md, task KY-6).
// A summary key (no property) stands for every track keyed at its frame. A move is FlareCore's `MoveKeyframe(owner:)`
// per key, leading-edge keys first, tried on a copy of the engine so one that lands a key on another throws and changes
// nothing. In a scene a key never moves past the scene's last frame; a symbol has no ruler of its own, so there only
// collisions and frames before 0 refuse. Several keys move as one "Move Keyframe" step, or merge into the drag's entry
// under `coalesceKey`. A remove is `RemoveKeyframe(owner:)` per key, grouped as one "Delete Keyframe". Agrees with
// `FakeKeyframes` on scenes; the `KeyframeEditing` conformance comes in KY-7.
import FlareCore

extension LiveKeyframes {
    public func moveKeys(_ keys: Set<KeyRef>, by delta: Int, owner: LayerOwner,
                         coalesceKey: String?, in engine: inout CommandEngine) throws {
        let moving = try Self.trackKeys(keys, owner: owner, in: engine.document)
        guard delta != 0, !moving.isEmpty else { return }
        var targets: [Int] = []
        for key in moving {
            let (to, overflow) = key.frame.addingReportingOverflow(delta)
            guard !overflow else { throw CommandError.invalidFrame(delta) }
            targets.append(to)
        }
        if case .scene(let sceneID) = owner {
            guard let scene = engine.document.scenes.first(where: { $0.id == sceneID }) else {
                throw CommandError.sceneNotFound(sceneID)
            }
            // A key past the scene's last frame would never play (#636).
            if delta > 0, let past = targets.filter({ $0 >= scene.durationFrames }).max() { throw CommandError.invalidFrame(past) }
        }
        // The leading edge moves first, so no key passes over one that has not moved yet.
        let ordered = moving.sorted { delta > 0 ? $0.frame > $1.frame : $0.frame < $1.frame }
        let commands = ordered.map {
            MoveKeyframe(owner: owner, layerID: $0.layerID, property: $0.property, from: $0.frame, to: $0.frame + delta)
        }
        var trial = engine
        if coalesceKey == nil, commands.count > 1 {
            try trial.group("Move Keyframe") { engine in
                for command in commands { try engine.perform(command) }
            }
        } else {
            for command in commands { try trial.perform(command, coalesceKey: coalesceKey) }
        }
        engine = trial
    }

    public func removeKeys(_ keys: Set<KeyRef>, owner: LayerOwner, in engine: inout CommandEngine) throws {
        let removing = try Self.trackKeys(keys, owner: owner, in: engine.document)
            .sorted { ($0.layerID, $0.property, $0.frame) < ($1.layerID, $1.property, $1.frame) }
        try engine.group("Delete Keyframe") { engine in
            for key in removing {
                try engine.perform(RemoveKeyframe(owner: owner, layerID: key.layerID, property: key.property, frame: key.frame))
            }
        }
    }

    /// One key on one track of the owner.
    private struct TrackKey: Hashable { var layerID: String, property: String, frame: Int }

    /// The track keys each `KeyRef` names. A summary key names the tracks keyed at its frame; a key on a named track
    /// that isn't there, or a layer the owner doesn't hold, throws.
    private static func trackKeys(_ keys: Set<KeyRef>, owner: LayerOwner, in document: Document) throws -> Set<TrackKey> {
        let layers = document.layers(of: owner) ?? []
        var found = Set<TrackKey>()
        for key in keys {
            guard let layer = layers.first(where: { $0.id == key.layerID }) else { throw CommandError.layerNotFound(key.layerID) }
            if let property = key.property {
                guard layer.tracks[property]?.contains(where: { $0.frame == key.frame }) == true else {
                    throw CommandError.keyframeNotFound(property: property, frame: key.frame)
                }
                found.insert(TrackKey(layerID: layer.id, property: property, frame: key.frame))
            } else {
                for (property, track) in layer.tracks where track.contains(where: { $0.frame == key.frame }) {
                    found.insert(TrackKey(layerID: layer.id, property: property, frame: key.frame))
                }
            }
        }
        return found
    }
}
