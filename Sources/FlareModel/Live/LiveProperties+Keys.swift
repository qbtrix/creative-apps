// LiveProperties+Keys.swift: the stopwatch and the keyframe button (docs/blueprints/flare/features/live-keys.md, KY-3).
// Section 2's rule, as in FakeProperties: a track with fewer than two keys is not animated, so the stopwatch keys the
// playhead (and the last frame, or 0, when that leaves one key); an animated track's stopwatch keeps one key at 0 holding
// the value at the playhead. Keys are FlareCore's `SetKeyframe` and `RemoveKeyframe` with the owner, so a symbol's own
// layers work like scene layers. The `PropertyAnimating` conformance lives in LiveProperties+Paint.swift.
import FlareCore

extension LiveProperties {
    /// The stopwatch: one group, "Animate <Title>" or "Stop Animating <Title>". Throws `layerNotFound` or `layerLocked`.
    public func toggleAnimated(_ property: String, owner: LayerOwner, layerID: String, frame: Int, lastFrame: Int,
                               in engine: inout CommandEngine) throws {
        let layer = try Self.keyable(layerID, owner: owner, in: engine.document)
        let keys = layer.tracks[property] ?? []
        let value = Self.sampled(property, of: layer, at: frame)
        func key(_ at: Int, _ engine: inout CommandEngine) throws {
            let easing = keys.first { $0.frame == at }?.easing ?? .linear
            try engine.perform(SetKeyframe(owner: owner, layerID: layerID, property: property,
                                           keyframe: Keyframe(frame: at, value: value, easing: easing)))
        }
        let title = FakeProperties.title(property)
        if keys.count >= 2 {
            try engine.group("Stop Animating \(title)") { engine in
                for old in keys where old.frame != 0 {
                    try engine.perform(RemoveKeyframe(owner: owner, layerID: layerID, property: property, frame: old.frame))
                }
                try key(0, &engine)
            }
        } else {
            try engine.group("Animate \(title)") { engine in
                try key(frame, &engine)
                // With no other key left, a second one at the last frame (or 0) makes the row animated.
                let other = frame == lastFrame ? 0 : lastFrame
                if keys.allSatisfy({ $0.frame == frame }), other != frame, other >= 0 { try key(other, &engine) }
            }
        }
    }

    /// The keyframe button: removes the key at `frame`, or keys the sampled value there. One undo entry either way.
    public func toggleKey(_ property: String, owner: LayerOwner, layerID: String, frame: Int,
                          in engine: inout CommandEngine) throws {
        let layer = try Self.keyable(layerID, owner: owner, in: engine.document)
        if (layer.tracks[property] ?? []).contains(where: { $0.frame == frame }) {
            try engine.perform(RemoveKeyframe(owner: owner, layerID: layerID, property: property, frame: frame))
        } else {
            let keyframe = Keyframe(frame: frame, value: Self.sampled(property, of: layer, at: frame))
            try engine.perform(SetKeyframe(owner: owner, layerID: layerID, property: property, keyframe: keyframe))
        }
    }

    /// The value `property` shows at `frame`, falling back to the standard default.
    private static func sampled(_ property: String, of layer: Layer, at frame: Int) -> Double {
        layer.sample(at: Double(frame))[property] ?? Layer.standardDefaults[property] ?? 0
    }

    /// The layer `id` of `owner`; throws `layerNotFound` when it is missing and `layerLocked` when it is locked.
    private static func keyable(_ id: String, owner: LayerOwner, in document: Document) throws -> Layer {
        guard let found = document.layers(of: owner)?.first(where: { $0.id == id }) else { throw CommandError.layerNotFound(id) }
        guard !found.isLocked else { throw CommandError.layerLocked(id) }
        return found
    }
}
