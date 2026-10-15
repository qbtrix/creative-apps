// LiveProperties.swift: the live inspector rows (docs/blueprints/flare/features/live-keys.md, KY-1). The rows, ranges,
// units and decimals are `FakeProperties.rows`; values come from FlareCore's `Layer.sample(at:)`, falling back to
// `Layer.standardDefaults`; key states follow section 2's rule (`FakeProperties.keyState`, a static read). Layers whose
// values or states differ give a Mixed row (nil value, not animated). Reads work on any owner, scene or symbol.
// The writes and the `PropertyAnimating` conformance come in KY-2 to KY-4.
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
}
