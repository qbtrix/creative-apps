// Fakes/FakeLayerPlacing.swift: the LayerPlacing views, snapshots and
// journeys run on. It answers through LiveLayerPlacing, so both come from
// HaloKeyRules and can't drift apart. Linux-safe; never used by `.live`.

public struct FakeLayerPlacing: LayerPlacing {
    private let live = LiveLayerPlacing()
    public init() {}
    public func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double? {
        live.value(property, of: layerID, in: composition, at: frame)
    }
    public func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix? {
        live.worldMatrix(of: layerID, in: composition, at: frame)
    }
    public func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String] {
        live.parentCandidates(for: layerID, in: composition)
    }

    /// Whether `layerID` follows `ancestorID` through its chain of parents
    /// (HaloKeyRules.follows; kept for the callers that name it here).
    static func follows(_ layerID: String, _ ancestorID: String, in composition: HaloComposition) -> Bool {
        HaloKeyRules.follows(layerID, ancestorID, in: composition)
    }
}
