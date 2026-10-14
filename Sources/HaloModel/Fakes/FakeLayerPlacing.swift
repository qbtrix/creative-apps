// Fakes/FakeLayerPlacing.swift: a small, predictable LayerPlacing, so views,
// snapshots and journeys run before the live type lands (#38). It samples
// tracks with FlareCore's Timeline, falls back to the layer's defaults and
// applies parents outermost last, stopping at a cycle. Linux-safe; never
// used by `.live`.
import FlareCore

public struct FakeLayerPlacing: LayerPlacing {
    public init() {}
    public func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double? {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else { return nil }
        if let track = layer.tracks[property.rawValue], let v = Timeline.value(of: track, at: Double(frame)) { return v }
        return layer.defaultValue(property, in: composition)
    }
    public func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix? {
        guard composition.layers.contains(where: { $0.id == layerID }) else { return nil }
        var matrix = localMatrix(of: layerID, in: composition, at: frame)
        var seen: Set<String> = [layerID]
        var next = composition.layers.first { $0.id == layerID }?.parentID
        while let parent = next, !seen.contains(parent), composition.layers.contains(where: { $0.id == parent }) {
            matrix = localMatrix(of: parent, in: composition, at: frame) * matrix
            seen.insert(parent)
            next = composition.layers.first { $0.id == parent }?.parentID
        }
        return matrix
    }
    public func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String] {
        composition.layers.map(\.id).filter { $0 != layerID && !Self.follows($0, layerID, in: composition) }
    }

    func localMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix {
        func v(_ p: HaloProperty) -> Double { value(p, of: layerID, in: composition, at: frame) ?? 0 }
        return HaloMatrix.translation(x: v(.x), y: v(.y)) * HaloMatrix.rotation(degrees: v(.rotation))
            * HaloMatrix.scale(x: v(.scaleX), y: v(.scaleY)) * HaloMatrix.translation(x: -v(.anchorX), y: -v(.anchorY))
    }

    /// Whether `layerID` follows `ancestorID` through its chain of parents.
    static func follows(_ layerID: String, _ ancestorID: String, in composition: HaloComposition) -> Bool {
        var seen: Set<String> = []
        var next = composition.layers.first { $0.id == layerID }?.parentID
        while let id = next, seen.insert(id).inserted {
            if id == ancestorID { return true }
            next = composition.layers.first { $0.id == id }?.parentID
        }
        return false
    }
}
