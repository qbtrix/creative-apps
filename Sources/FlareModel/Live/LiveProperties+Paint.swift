// LiveProperties+Paint.swift: FILL and STROKE (docs/blueprints/flare/features/live-keys.md, KY-4). Each write is one
// undo group over FlareCore's `SetShapeFill` / `SetShapeStroke`, one command per `.shape(i)` address the caller passes
// (the workspace sends one per shape of a selected layer, or the direct-selected items). Other addresses are skipped;
// with no shape at all the write is a no-op that adds no undo entry. A negative or non-finite width throws "Stroke width
// can't be negative." before any write; `SetShapeStroke` validates the rest, and a bad stroke rolls the group back. This file also completes the `PropertyAnimating` conformance.
import FlareCore

extension LiveProperties: PropertyAnimating {}

extension LiveProperties {
    /// Grouped "Set Fill": `fill` on every shape address in `items`.
    public func setFill(_ fill: Fill, of items: [StageAddress], in engine: inout CommandEngine) throws {
        let shapes = Self.shapes(items)
        guard !shapes.isEmpty else { return }
        try engine.group("Set Fill") { engine in
            for (a, i) in shapes { try engine.perform(SetShapeFill(owner: a.owner, layerID: a.layerID, index: i, fill: fill)) }
        }
    }

    /// Grouped "Set Stroke": `stroke` (nil removes it) on every shape address in `items`.
    public func setStroke(_ stroke: Stroke?, of items: [StageAddress], in engine: inout CommandEngine) throws {
        let shapes = Self.shapes(items)
        guard !shapes.isEmpty else { return }
        if let s = stroke, !(s.width.isFinite && s.width >= 0) {
            throw CommandError.invalidDocument("Stroke width can't be negative.")
        }
        try engine.group("Set Stroke") { engine in
            for (a, i) in shapes {
                try engine.perform(SetShapeStroke(owner: a.owner, layerID: a.layerID, index: i, stroke: stroke))
            }
        }
    }

    /// The shape addresses in `items`, each with its shape index, in order.
    private static func shapes(_ items: [StageAddress]) -> [(StageAddress, Int)] {
        items.compactMap { a in if case .shape(let i) = a.item { (a, i) } else { nil } }
    }
}
