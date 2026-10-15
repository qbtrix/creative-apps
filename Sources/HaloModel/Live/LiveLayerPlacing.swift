// Live/LiveLayerPlacing.swift: the W0 stub of LayerPlacing. It places
// nothing and says why; the layer inspector feature (#38) replaces this file
// whole with the live type. Linux-safe.

public struct LiveLayerPlacing: LayerPlacing {
    public init() {}
    public var unavailableHelp: String? { "Layer transforms arrive with the layer inspector (#38)." }
    public func value(_ property: HaloProperty, of layerID: String, in composition: HaloComposition, at frame: Int) -> Double? { nil }
    public func worldMatrix(of layerID: String, in composition: HaloComposition, at frame: Int) -> HaloMatrix? { nil }
    public func parentCandidates(for layerID: String, in composition: HaloComposition) -> [String] { [] }
}
