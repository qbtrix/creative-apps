// KeyframeEditing+Kernel.swift: AE-f1 (#1937). Live and Fake keyframes decide with SuiteKernel's `KeyRules`, then emit
// FlareCore's commands; Flare's own rules (range before collision, insert moves the key at its frame) stay here.
import FlareCore
import SuiteKernel

typealias TrackKey = SuiteKernel.KeyRef<String>

enum KernelKeys {
    /// The track keys `keys` name; a missing layer, or a named key that isn't there, throws.
    static func trackKeys(_ keys: Set<KeyRef>, owner: LayerOwner, in document: Document) throws -> Set<TrackKey> {
        var found = Set<TrackKey>()
        for key in keys {
            let layer = document.layers(of: owner)?.first { $0.id == key.layerID }
            guard let layer else { throw CommandError.layerNotFound(key.layerID) }
            if let name = key.property, layer.tracks[name]?.contains(where: { $0.frame == key.frame }) != true {
                throw CommandError.keyframeNotFound(property: name, frame: key.frame)
            }
            for name in key.easedProperties(in: layer) { found.insert(TrackKey(layerID: layer.id, track: .property(name), frame: key.frame)) }
        }
        return found
    }

    /// Moves `keys` by `delta`: one "Move Keyframe" step, or one command per key into `coalesceKey`'s entry, on a copy
    /// of the engine so a refused or failing move changes nothing. Keys land at `lower` or later and, moving later,
    /// before `end(document)`; outside that throws `pastRange(moving)`. Live and Fake differ only in those three.
    static func move(_ keys: Set<KeyRef>, by delta: Int, owner: LayerOwner, coalesceKey: String?, from lower: Int,
                     before end: (Document) throws -> Int, pastRange: (Set<TrackKey>) -> any Error,
                     in engine: inout CommandEngine) throws {
        let moving = try trackKeys(keys, owner: owner, in: engine.document)
        guard delta != 0, !moving.isEmpty else { return }
        guard moving.allSatisfy({ !$0.frame.addingReportingOverflow(delta).overflow }) else { throw CommandError.invalidFrame(delta) }
        let end = try end(engine.document)
        let last = delta > 0 ? end : Int.max
        guard lower < last else { throw pastRange(moving) }
        switch moveRefusal(moving, by: delta, in: engine.document.layers(of: owner) ?? [], range: lower...(last - 1)) {
        case (.pastRange, _)?: throw pastRange(moving)
        case (.collides(let frame), let property)?: throw CommandError.frameOccupied(property: property, frame: frame)
        case nil: break
        }
        let commands = moves(moving, by: delta, owner: owner)
        func write(_ engine: inout CommandEngine) throws {
            for command in commands { try engine.perform(command, coalesceKey: coalesceKey) }
        }
        var trial = engine
        if coalesceKey == nil, commands.count > 1 { try trial.group("Move Keyframe", write) } else { try write(&trial) }
        engine = trial
    }

    /// Removes `keys` as one "Delete Keyframe" step; a track's only key stays (`.singleStays`).
    static func remove(_ keys: Set<KeyRef>, owner: LayerOwner, in engine: inout CommandEngine) throws {
        let removing = try trackKeys(keys, owner: owner, in: engine.document)
        try engine.group("Delete Keyframe") { engine in
            for removal in removals(removing, owner: owner, in: engine.document.layers(of: owner) ?? []) { try engine.perform(removal) }
        }
    }

    /// Drops `layer`'s keys in the `count` frames from `frame` and shifts its later keys back, inside the caller's step.
    static func removeFrames(_ count: Int, at frame: Int, from layer: Layer, owner: LayerOwner,
                             in engine: inout CommandEngine) throws {
        for (property, keys) in layer.tracks.sorted(by: { $0.key < $1.key }) {
            for key in dropped(byRemoving: count, at: frame, from: keys) {
                try engine.perform(RemoveKeyframe(owner: owner, layerID: layer.id, property: property, frame: key.frame))
            }
        }
        let end = count > Int.max - frame ? Int.max : frame + count  // the first frame after the removed run
        guard let last = lastKey(of: layer), last >= end else { return }
        try engine.perform(ShiftKeyframes(owner: owner, layerID: layer.id, fromFrame: end, toFrame: last, delta: -count))
    }

    /// `layer`'s last key on any track; nil with none.
    static func lastKey(of layer: Layer) -> Int? { layer.tracks.values.flatMap { $0.map(\.frame) }.max() }

    /// Why `KeyRules.moveKeys` refuses, with the track's property; every track meets the range before any collision.
    private static func moveRefusal(_ keys: Set<TrackKey>, by delta: Int, in layers: [Layer],
                            range: ClosedRange<Int>) -> (refusal: KeyRefusal, property: String)? {
        for withStaying in [false, true] {
            for group in byTrack(keys) {
                let track = layers.first { $0.id == group.layerID }?.tracks[group.property] ?? []
                var tracks = [group.property: withStaying ? track : track.filter { group.frames.contains($0.frame) }]
                do { try KeyRules.moveKeys(&tracks, group.frames, by: delta, clampedTo: range) } catch { return (error, group.property) }
            }
        }
        return nil
    }

    /// One `MoveKeyframe` per key, the leading edge first, so no key passes over one that has not moved yet.
    private static func moves(_ keys: Set<TrackKey>, by delta: Int, owner: LayerOwner) -> [MoveKeyframe] {
        keys.sorted { a, b in
            a.frame != b.frame ? (delta > 0) == (a.frame > b.frame) : (a.layerID, a.property ?? "") < (b.layerID, b.property ?? "")
        }.map { MoveKeyframe(owner: owner, layerID: $0.layerID, property: $0.property ?? "", from: $0.frame, to: $0.frame + delta) }
    }

    /// One `RemoveKeyframe` per key `KeyRules.removeKeys` drops, by layer, property, frame.
    private static func removals(_ keys: Set<TrackKey>, owner: LayerOwner, in layers: [Layer]) -> [RemoveKeyframe] {
        byTrack(keys).flatMap { group in
            let track = layers.first { $0.id == group.layerID }?.tracks[group.property] ?? []
            var left = track
            KeyRules.removeKeys(&left, group.frames, leaving: .singleStays)
            return Set(track.map(\.frame)).subtracting(left.map(\.frame)).sorted().map {
                RemoveKeyframe(owner: owner, layerID: group.layerID, property: group.property, frame: $0)
            }
        }
    }

    /// `layer`'s last key once `count` frames go in at `frame`: the kernel's insert after the frame before. Saturates.
    static func lastKey(afterInserting count: Int, at frame: Int, in layer: Layer) -> Int? {
        let before = frame > Int.min ? frame - 1 : frame
        return layer.tracks.values.compactMap { var moved = $0; KeyRules.insertFrames(&moved, count, at: before); return moved.map(\.frame).max() }.max()
    }

    /// The keys of `track` that `KeyRules.removeFrames` drops, in track order.
    private static func dropped(byRemoving count: Int, at frame: Int, from track: [Keyframe]) -> [Keyframe] {
        var scratch = track.indices.map { Keyframe(frame: track[$0].frame, value: Double($0)) }
        KeyRules.removeFrames(&scratch, count, at: frame)
        let kept = Set(scratch.map { Int($0.value) })
        return track.indices.filter { !kept.contains($0) }.map { track[$0] }
    }

    private static func byTrack(_ keys: Set<TrackKey>) -> [(layerID: String, property: String, frames: Set<Int>)] {
        Dictionary(grouping: keys, by: \.layerID).sorted { $0.key < $1.key }.flatMap { id, onLayer in
            Dictionary(grouping: onLayer) { $0.property ?? "" }.sorted { $0.key < $1.key }
                .map { (layerID: id, property: $0.key, frames: Set($0.value.map(\.frame))) }
        }
    }
}
