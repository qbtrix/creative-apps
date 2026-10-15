// LiveKeyframes.swift: the live timeline reads (docs/blueprints/flare/features/live-keys.md, task KY-5). A row per
// layer of any owner (a scene or a symbol): its summary diamonds are the union of every track's key frames, a segment
// joins each pair of consecutive diamonds, and a segment's easing is the first track (by name) that tweens out of its
// start key with a non-linear easing. Labels are the scene's own. Writes and the `KeyframeEditing` conformance come
// in KY-6 and KY-7. Agrees with `FakeKeyframes` on the fixtures.
import FlareCore

public struct LiveKeyframes: Sendable {
    public init() {}

    public func rows(_ document: Document, owner: LayerOwner) -> [TimelineRow] {
        guard let layers = document.layers(of: owner) else { return [] }
        return layers.map(Self.row)
    }

    public func labels(_ document: Document, sceneID: String) -> [String: Int] {
        for scene in document.scenes where scene.id == sceneID { return scene.labels }
        return [:]
    }

    private static func row(_ layer: Layer) -> TimelineRow {
        var keyed = Set<Int>()
        for keys in layer.tracks.values { keyed.formUnion(keys.map(\.frame)) }
        let diamonds = keyed.sorted()
        var segments: [ClosedRange<Int>] = []
        var eased: [Int: Easing] = [:]
        let tracks = layer.tracks.keys.sorted().compactMap { layer.tracks[$0] }
        for (start, end) in zip(diamonds, diamonds.dropFirst()) {
            segments.append(start...end)
            if let easing = easing(out: start, tracks: tracks) { eased[start] = easing }
        }
        return TimelineRow(layerID: layer.id, name: layer.name, isVisible: layer.isVisible, isLocked: layer.isLocked,
                           keyFrames: diamonds, segments: segments, easedSegments: eased)
    }

    /// The easing of the first track (in the given order) with a key at `start` and a later key, when it isn't linear.
    private static func easing(out start: Int, tracks: [[Keyframe]]) -> Easing? {
        for keys in tracks where keys.contains(where: { $0.frame > start }) {
            guard let key = keys.first(where: { $0.frame == start }), key.easing != .linear else { continue }
            return key.easing
        }
        return nil
    }
}
