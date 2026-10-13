// FakeEasing.swift: KeyframeEasing over the real engine (docs/blueprints/flare.md, 6.3), the member
// `FlareServices.easing` holds. The six `EasingPreset`s, a curve sampled from `Easing.value(at:)`, and FlareCore's
// `SetKeyframeEasing`. A summary key (no property) sets every track keyed at its frame. `FakeEasingEditing` stays the
// window-level `EasingEditing` stand-in; this is not it. With `unavailable` set, reads are empty and writes throw it.
import FlareCore

public struct FakeEasing: KeyframeEasing {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    public var presets: [EasingPreset] { unavailable == nil ? EasingPreset.allCases : [] }

    public func curve(_ easing: Easing, count: Int) -> [Point] {
        guard unavailable == nil, count > 0 else { return [] }
        let last = Double(max(count - 1, 1))
        return (0..<count).map { Point(x: Double($0) / last, y: easing.value(at: Double($0) / last)) }
    }

    public func setEasing(_ easing: Easing, at key: KeyRef, owner: LayerOwner,
                          coalesceKey: String?, in engine: inout CommandEngine) throws {
        if let unavailable { throw NotBuilt(reason: unavailable) }
        guard case .scene(let sceneID) = owner else { throw CommandError.invalidDocument(FakeProperties.symbolKeys) }
        guard let layer = engine.document.layers(of: owner)?.first(where: { $0.id == key.layerID }) else {
            throw CommandError.layerNotFound(key.layerID)
        }
        let properties = key.property.map { [$0] }
            ?? layer.tracks.filter { $0.value.contains { $0.frame == key.frame } }.keys.sorted()
        guard !properties.isEmpty else { throw CommandError.keyframeNotFound(property: "", frame: key.frame) }
        func write(_ engine: inout CommandEngine) throws {
            for property in properties {
                try engine.perform(SetKeyframeEasing(sceneID: sceneID, layerID: key.layerID, property: property,
                                                     frame: key.frame, easing: easing), coalesceKey: coalesceKey)
            }
        }
        if coalesceKey == nil, properties.count > 1 { try engine.group("Set Keyframe Easing", write) } else { try write(&engine) }
    }
}
