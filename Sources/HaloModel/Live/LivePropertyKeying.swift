// Live/LivePropertyKeying.swift: the live PropertyKeying (#38). Its rows,
// typed values, stopwatch and key diamond are real, all from HaloKeyRules
// (values sampled by FlareCore, section 2's not-animated rule). Parenting
// still throws `.notBuilt` and changes nothing until it lands. Linux-safe.

public struct LivePropertyKeying: PropertyKeying {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] {
        HaloKeyRules.rows(for: layerID, in: composition, at: frame)
    }
    public func setValue(
        _ value: Double, for property: HaloProperty, of layerID: String, at frame: Int,
        in composition: inout HaloComposition
    ) throws {
        try HaloKeyRules.setValue(value, for: property, of: layerID, at: frame, in: &composition)
    }
    public func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        try HaloKeyRules.toggleAnimation(property, of: layerID, at: frame, in: &composition)
    }
    public func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        try HaloKeyRules.toggleKey(property, of: layerID, at: frame, in: &composition)
    }
    public func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        throw HaloEditError.notBuilt("Parenting")
    }
}
