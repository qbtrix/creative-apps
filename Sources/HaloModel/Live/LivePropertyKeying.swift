// Live/LivePropertyKeying.swift: the W0 stub of PropertyKeying. Every write
// throws `.notBuilt` and changes nothing; the layer inspector feature (#38)
// replaces this file whole with the live type. Linux-safe.

public struct LivePropertyKeying: PropertyKeying {
    public init() {}
    public var unavailableHelp: String? { "Keys arrive with the layer inspector (#38)." }
    public func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] { [] }
    public func setValue(
        _ value: Double, for property: HaloProperty, of layerID: String, at frame: Int,
        in composition: inout HaloComposition
    ) throws {
        throw HaloEditError.notBuilt("Keying")
    }
    public func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        throw HaloEditError.notBuilt("Keying")
    }
    public func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        throw HaloEditError.notBuilt("Keying")
    }
    public func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        throw HaloEditError.notBuilt("Parenting")
    }
}
