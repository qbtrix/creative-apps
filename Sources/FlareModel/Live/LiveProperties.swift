// LiveProperties.swift: the live inspector rows (docs/blueprints/flare/features/live-keys.md, KY-1). The rows, ranges,
// units and decimals are `FakeProperties.rows`; values come from FlareCore's `Layer.sample(at:)`, falling back to
// `Layer.standardDefaults`; key states follow section 2's rule (`FakeProperties.keyState`, a static read). Layers whose
// values or states differ give a Mixed row (nil value, not animated). Reads and `setValue` (KY-2) work on any owner,
// scene or symbol. The stopwatch and keyframe button live in LiveProperties+Keys.swift (KY-3); fill, stroke and the
// `PropertyAnimating` conformance live in LiveProperties+Paint.swift (KY-4). A coalesced multi-layer scrub is one undo
// entry, but FlareCore merges only into the entry's last command, so the entry holds one command per layer per step: a
// known memory cost, not a correctness issue.
import FlareCore

public struct LiveProperties: Sendable {
    public init() {}

    /// The TRANSFORM rows for the selected layers of `owner` at `frame`; [] when no selected layer exists there.
    public func properties(_ document: Document, owner: LayerOwner, layerIDs: [String], frame: Int) -> [AnimatedProperty] {
        let layers = (document.layers(of: owner) ?? []).filter { layerIDs.contains($0.id) }
        guard !layers.isEmpty else { return [] }
        let samples = layers.map { $0.sample(at: Double(frame)) }
        return FakeProperties.rows.map { row in
            let values = samples.map { $0[row.name] ?? Layer.standardDefaults[row.name] ?? 0 }
            let states = layers.map { FakeProperties.keyState(row.name, of: $0, frame: frame) }
            let same = values.allSatisfy { $0 == values.first } && states.allSatisfy { $0 == states.first }
            return AnimatedProperty(name: row.name, title: row.title, value: same ? values.first : nil, range: row.range,
                                    unit: row.unit, decimals: row.decimals,
                                    keyState: same ? states.first ?? .notAnimated : .notAnimated)
        }
    }

    /// Section 2's rule: with two or more keys on the track, or auto-key on, the value is keyed at `frame`; otherwise
    /// the track's one key (frame 0 when there is none) takes it, keeping its easing. A non-finite value throws
    /// "<Title> needs a number." and a frame before 0 throws `invalidFrame`, changing nothing; there is no clamp. Each layer's write is a top-level
    /// `SetKeyframe` with `coalesceKey`, so a scrub is one entry; with no key, several layers are one "Set Keyframe".
    public func setValue(_ value: Double, of property: String, owner: LayerOwner, layerIDs: [String], frame: Int,
                         autoKey: Bool, coalesceKey: String?, in engine: inout CommandEngine) throws {
        guard value.isFinite else { throw CommandError.invalidDocument("\(FakeProperties.title(property)) needs a number.") }
        guard frame >= 0 else { throw CommandError.invalidFrame(frame) }
        let targets = try Self.editable(layerIDs, owner: owner, in: engine.document)
        let writes: [SetKeyframe] = targets.map { layer in
            let track = layer.tracks[property] ?? []
            let at = (autoKey || track.count >= 2) ? frame : (track.first?.frame ?? 0)
            let kept = track.first { $0.frame == at }?.easing ?? .linear
            return SetKeyframe(owner: owner, layerID: layer.id, property: property,
                               keyframe: Keyframe(frame: at, value: value, easing: kept))
        }
        if coalesceKey == nil, writes.count > 1 {
            try engine.group("Set Keyframe") { engine in for write in writes { try engine.perform(write) } }
        } else {
            // Tried on a copy, so a later layer that throws leaves no key and no entry behind.
            var trial = engine
            for write in writes { try trial.perform(write, coalesceKey: coalesceKey) }
            engine = trial
        }
    }

    /// The layers of `owner` named in `ids`, in the owner's order; throws `layerNotFound` or `layerLocked` first.
    private static func editable(_ ids: [String], owner: LayerOwner, in document: Document) throws -> [Layer] {
        let layers = document.layers(of: owner) ?? []
        for id in ids {
            guard let match = layers.first(where: { $0.id == id }) else { throw CommandError.layerNotFound(id) }
            if match.isLocked { throw CommandError.layerLocked(id) }
        }
        return layers.filter { ids.contains($0.id) }
    }
}
