// LiveProperties+Paint.swift: FILL and STROKE (docs/blueprints/flare/features/live-keys.md, KY-4). Each write is one
// undo group over FlareCore's `SetShapeFill` / `SetShapeStroke`, one command per `.shape(i)` address the caller passes
// (the workspace sends one per shape of a selected layer, or the direct-selected items). A stroke write with a
// `coalesceKey` performs each command top-level under that key instead, on a copy of the engine, so a width drag is one
// undo entry (one command per shape per sample, since `SetShapeStroke` doesn't merge). Other addresses are skipped;
// with no shape at all the write is a no-op that adds no undo entry. Before any write, a non-finite width throws "Stroke
// width needs a number.", a negative one "Stroke width can't be negative." and a non-finite color channel "Each stroke
// color channel needs a number."; a nil stroke is the "Remove Stroke" step, as FlareCore names it. This file also
// completes the `PropertyAnimating` conformance, and adds `keyPaint`, a paint edit's keys (TK-7).
import FlareCore

extension LiveProperties: PropertyAnimating {}

/// A fill or stroke colour key, or a stroke width key, at `frame` on a shape; a nil value removes the key there.
public enum PaintKeyWrite: Sendable, Equatable {
    case color(StageAddress, TrackTarget, frame: Int, FlareColor?)
    case width(StageAddress, shape: Int, frame: Int, Double?)
}

extension PropertyAnimating {
    /// Performs `writes` in order, keeping a replaced key's easing; with `coalesceKey` a Width drag's keys merge.
    public func keyPaint(_ writes: [PaintKeyWrite], coalesceKey: String?, in engine: inout CommandEngine) throws {
        for write in writes {
            switch write {
            case let .color(a, target, frame, value?):
                let easing = Self.layer(a, engine)?.colorTracks[target.key]?.first { $0.frame == frame }?.easing
                try engine.perform(SetColorKeyframe(owner: a.owner, layerID: a.layerID, target: target, frame: frame,
                                                    value: value, easing: easing ?? .linear), coalesceKey: coalesceKey)
            case let .color(a, target, frame, nil):
                try engine.perform(RemoveColorKeyframe(owner: a.owner, layerID: a.layerID, target: target, frame: frame))
            case let .width(a, i, frame, value?):
                let property = Layer.trackKey(strokeWidthOf: i)
                let easing = Self.layer(a, engine)?.tracks[property]?.first { $0.frame == frame }?.easing
                let key = Keyframe(frame: frame, value: value, easing: easing ?? .linear)
                try engine.perform(SetKeyframe(owner: a.owner, layerID: a.layerID, property: property, keyframe: key),
                                   coalesceKey: coalesceKey)
            case let .width(a, i, frame, nil):
                try engine.perform(RemoveKeyframe(owner: a.owner, layerID: a.layerID,
                                                  property: Layer.trackKey(strokeWidthOf: i), frame: frame))
            }
        }
    }

    private static func layer(_ a: StageAddress, _ e: CommandEngine) -> Layer? { e.document.layers(of: a.owner)?.first { $0.id == a.layerID } }
}

extension LiveProperties {
    /// Grouped "Set Fill": `fill` on every shape address in `items`.
    public func setFill(_ fill: Fill, of items: [StageAddress], in engine: inout CommandEngine) throws {
        let shapes = Self.shapes(items)
        guard !shapes.isEmpty else { return }
        try engine.group("Set Fill") { engine in
            for (a, i) in shapes { try engine.perform(SetShapeFill(owner: a.owner, layerID: a.layerID, index: i, fill: fill)) }
        }
    }

    /// Grouped "Set Stroke": `stroke` (nil removes it) on every shape address in `items`; with `coalesceKey`, merged
    /// into that key's open entry.
    public func setStroke(_ stroke: Stroke?, of items: [StageAddress], coalesceKey: String?,
                          in engine: inout CommandEngine) throws {
        let shapes = Self.shapes(items)
        guard !shapes.isEmpty else { return }
        if let s = stroke {
            guard s.width.isFinite else { throw CommandError.invalidDocument("Stroke width needs a number.") }
            guard s.width >= 0 else { throw CommandError.invalidDocument("Stroke width can't be negative.") }
            guard s.color.isFinite else {
                throw CommandError.invalidDocument("Each stroke color channel needs a number.")
            }
        }
        let writes = shapes.map { a, i in SetShapeStroke(owner: a.owner, layerID: a.layerID, index: i, stroke: stroke) }
        if let coalesceKey {
            // Tried on a copy, so a later shape that throws leaves no change and no entry behind.
            var trial = engine
            for write in writes { try trial.perform(write, coalesceKey: coalesceKey) }
            return engine = trial
        }
        try engine.group(stroke == nil ? "Remove Stroke" : "Set Stroke") { engine in
            for write in writes { try engine.perform(write) }
        }
    }

    /// The shape addresses in `items`, each with its shape index, in order.
    private static func shapes(_ items: [StageAddress]) -> [(StageAddress, Int)] {
        items.compactMap { a in if case .shape(let i) = a.item { (a, i) } else { nil } }
    }
}
