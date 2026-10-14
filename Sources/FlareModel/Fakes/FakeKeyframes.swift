// FakeKeyframes.swift: KeyframeEditing over the real engine (docs/blueprints/flare.md, 6.3). Rows come from
// `Layer.tracks`; moves, removes, frame inserts and removes, and labels are FlareCore's `MoveKeyframe`,
// `RemoveKeyframe`, `ShiftKeyframes`, `SetFrameLabel` and `RemoveFrameLabel`. A summary key (no property) stands for
// every track keyed at its frame. A move runs on a copy of the engine, so one that would land a key on another key
// throws and changes nothing. A frame insert that pushes a key past the scene's last frame grows the scene in the same
// step (`SetSceneTiming`), so the final pose still plays. Keyframe commands take scene layers only, so a symbol owner throws until
// they take an owner (LC-5). With `unavailable` set, reads are empty and every write throws it.
import FlareCore

public struct FakeKeyframes: KeyframeEditing {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    /// One key on one track.
    private struct TrackKey: Hashable { var layerID: String, property: String, frame: Int }

    private func available() throws { if let unavailable { throw NotBuilt(reason: unavailable) } }

    public func rows(_ document: Document, owner: LayerOwner) -> [TimelineRow] {
        guard unavailable == nil else { return [] }
        return (document.layers(of: owner) ?? []).map { layer in
            let frames = Set(layer.tracks.values.flatMap { $0.map(\.frame) }).sorted()
            let segments = zip(frames, frames.dropFirst()).map { $0...$1 }
            // A segment's easing: the first track (by name) that tweens out of its start key with a non-linear one.
            var eased: [Int: Easing] = [:]
            for start in frames.dropLast() {
                eased[start] = layer.tracks.sorted { $0.key < $1.key }.lazy
                    .compactMap { _, keys in keys.contains { $0.frame > start } ? keys.first { $0.frame == start }?.easing : nil }
                    .first { $0 != .linear }
            }
            return TimelineRow(layerID: layer.id, name: layer.name, isVisible: layer.isVisible, isLocked: layer.isLocked,
                               keyFrames: frames, segments: segments, easedSegments: eased)
        }
    }

    public func labels(_ document: Document, sceneID: String) -> [String: Int] {
        guard unavailable == nil else { return [:] }
        return document.scenes.first { $0.id == sceneID }?.labels ?? [:]
    }

    public func moveKeys(_ keys: Set<KeyRef>, by delta: Int, owner: LayerOwner,
                         coalesceKey: String?, in engine: inout CommandEngine) throws {
        try available()
        let sceneID = try Self.scene(owner)
        let moving = try Self.expand(keys, owner: owner, in: engine.document)
        guard delta != 0, !moving.isEmpty else { return }
        guard moving.allSatisfy({ !$0.frame.addingReportingOverflow(delta).overflow }) else { throw CommandError.invalidFrame(delta) }
        // Keys at the leading edge move first, so no key passes over one that has not moved yet.
        let ordered = moving.sorted { delta > 0 ? $0.frame > $1.frame : $0.frame < $1.frame }
        func write(_ engine: inout CommandEngine) throws {
            for key in ordered {
                try engine.perform(MoveKeyframe(sceneID: sceneID, layerID: key.layerID, property: key.property,
                                                from: key.frame, to: key.frame + delta), coalesceKey: coalesceKey)
            }
        }
        // On a copy, so a move that fails part way (a key landing on another, say) leaves the engine as it was.
        var trial = engine
        if coalesceKey == nil, ordered.count > 1 { try trial.group("Move Keyframe", write) } else { try write(&trial) }
        engine = trial
    }

    public func removeKeys(_ keys: Set<KeyRef>, owner: LayerOwner, in engine: inout CommandEngine) throws {
        try available()
        let sceneID = try Self.scene(owner)
        let removing = try Self.expand(keys, owner: owner, in: engine.document)
        try engine.group("Delete Keyframe") { engine in
            for key in removing.sorted(by: { ($0.layerID, $0.property, $0.frame) < ($1.layerID, $1.property, $1.frame) }) {
                try engine.perform(RemoveKeyframe(sceneID: sceneID, layerID: key.layerID, property: key.property, frame: key.frame))
            }
        }
    }

    public func insertFrames(_ count: Int, at frame: Int, layerIDs: [String], owner: LayerOwner,
                             in engine: inout CommandEngine) throws {
        try available()
        let sceneID = try Self.scene(owner)
        let layers = try Self.frameEdit(count, at: frame, layerIDs: layerIDs, owner: owner, in: engine.document)
        let shifted = layers.compactMap(Self.lastFrame).filter { $0 >= frame }
        guard let scene = engine.document.scenes.first(where: { $0.id == sceneID }) else { throw CommandError.sceneNotFound(sceneID) }
        // The scene grows so a key pushed past its last frame still plays (#596).
        var duration = scene.durationFrames
        if let last = shifted.max() {
            let (end, overflow) = last.addingReportingOverflow(count)
            guard !overflow, end < Int.max else { throw CommandError.invalidFrame(count) }
            duration = max(duration, end + 1)
        }
        try engine.group("Insert Frame") { engine in
            for layer in layers {
                guard let last = Self.lastFrame(of: layer), last >= frame else { continue }
                try engine.perform(ShiftKeyframes(sceneID: sceneID, layerID: layer.id, fromFrame: frame, toFrame: last, delta: count))
            }
            if duration != scene.durationFrames {
                try engine.perform(SetSceneTiming(sceneID: sceneID, fps: scene.fps, durationFrames: duration))
            }
        }
    }

    public func removeFrames(_ count: Int, at frame: Int, layerIDs: [String], owner: LayerOwner,
                             in engine: inout CommandEngine) throws {
        try available()
        let sceneID = try Self.scene(owner)
        let layers = try Self.frameEdit(count, at: frame, layerIDs: layerIDs, owner: owner, in: engine.document)
        let end = count > Int.max - frame ? Int.max : frame + count  // the first frame after the removed run
        try engine.group("Remove Frame") { engine in
            for layer in layers {
                for (property, keys) in layer.tracks.sorted(by: { $0.key < $1.key }) {
                    for key in keys where key.frame >= frame && key.frame < end {
                        try engine.perform(RemoveKeyframe(sceneID: sceneID, layerID: layer.id, property: property, frame: key.frame))
                    }
                }
                guard let last = Self.lastFrame(of: layer), last >= end else { continue }
                try engine.perform(ShiftKeyframes(sceneID: sceneID, layerID: layer.id, fromFrame: end, toFrame: last, delta: -count))
            }
        }
    }

    public func setLabel(_ name: String?, at frame: Int, sceneID: String, in engine: inout CommandEngine) throws {
        try available()
        guard let scene = engine.document.scenes.first(where: { $0.id == sceneID }) else { throw CommandError.sceneNotFound(sceneID) }
        if let name, name.isEmpty { throw CommandError.invalidDocument("A label needs a name.") }
        // One label per frame: naming a frame replaces the label already there.
        let here = scene.labels.filter { $0.value == frame && $0.key != name }.keys.sorted()
        try engine.group(name == nil ? "Remove Frame Label" : "Set Frame Label") { engine in
            for old in here { try engine.perform(RemoveFrameLabel(sceneID: sceneID, name: old)) }
            if let name { try engine.perform(SetFrameLabel(sceneID: sceneID, name: name, frame: frame)) }
        }
    }

    /// Each `KeyRef` as the track keys it names; a summary key names every track keyed at its frame.
    private static func expand(_ keys: Set<KeyRef>, owner: LayerOwner, in document: Document) throws -> Set<TrackKey> {
        let layers = document.layers(of: owner) ?? []
        var out = Set<TrackKey>()
        for key in keys {
            guard let layer = layers.first(where: { $0.id == key.layerID }) else { throw CommandError.layerNotFound(key.layerID) }
            let properties = key.property.map { [$0] } ?? Array(layer.tracks.keys)
            for property in properties {
                guard layer.tracks[property]?.contains(where: { $0.frame == key.frame }) == true else {
                    if key.property == nil { continue }
                    throw CommandError.keyframeNotFound(property: property, frame: key.frame)
                }
                out.insert(TrackKey(layerID: layer.id, property: property, frame: key.frame))
            }
        }
        return out
    }

    private static func lastFrame(of layer: Layer) -> Int? { layer.tracks.values.flatMap { $0.map(\.frame) }.max() }

    private static func scene(_ owner: LayerOwner) throws -> String {
        guard case .scene(let id) = owner else { throw CommandError.invalidDocument(FakeProperties.symbolKeys) }
        return id
    }

    /// The layers a frame insert or remove edits, in the owner's order: none for a count under 1. Throws for a frame
    /// before 0 or a missing layer.
    private static func frameEdit(_ count: Int, at frame: Int, layerIDs ids: [String], owner: LayerOwner,
                                  in document: Document) throws -> [Layer] {
        guard frame >= 0 else { throw CommandError.invalidFrame(frame) }
        let all = count > 0 ? document.layers(of: owner) ?? [] : []
        if let missing = ids.first(where: { id in !all.contains { $0.id == id } }) { throw CommandError.layerNotFound(missing) }
        return all.filter { ids.contains($0.id) }
    }
}
