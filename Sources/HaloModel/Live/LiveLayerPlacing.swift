// Live/LiveLayerPlacing.swift: the live LayerPlacing (#38). Every answer
// comes from HaloKeyRules: tracks sampled with FlareCore's Timeline, the
// layer's defaults with no track, and world matrices through the parent
// chain, stopping at a cycle. Linux-safe.

public struct LiveLayerPlacing: LayerPlacing {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double? {
        HaloKeyRules.layer(layerID, in: composition).map { HaloKeyRules.value(property, of: $0, in: composition, at: frame) }
    }
    public func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix? {
        HaloKeyRules.worldMatrix(of: layerID, in: composition, at: frame)
    }
    public func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String] {
        HaloKeyRules.parentCandidates(for: layerID, in: composition)
    }
}
