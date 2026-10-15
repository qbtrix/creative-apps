// Fakes/FakePropertyKeying.swift: a small, predictable PropertyKeying (#38):
// the TRANSFORM rows, typed values, the stopwatch, the key diamond and the
// parent picker, keeping each protocol doc comment's rules. Its rows and
// writes, parenting included, come from LivePropertyKeying (HaloKeyRules),
// so fake and live can't drift. Linux-safe; never used by `.live`.

public struct FakePropertyKeying: PropertyKeying {
    private let live = LivePropertyKeying()
    public init() {}
    public func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] {
        live.rows(for: layerID, in: composition, at: frame)
    }
    public func setValue(
        _ value: Double, for property: HaloProperty, of layerID: String, at frame: Int,
        in composition: inout HaloComposition
    ) throws {
        try live.setValue(value, for: property, of: layerID, at: frame, in: &composition)
    }
    public func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        try live.toggleAnimation(property, of: layerID, at: frame, in: &composition)
    }
    public func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        try live.toggleKey(property, of: layerID, at: frame, in: &composition)
    }
    public func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        try live.setParent(parentID, of: layerID, at: frame, in: &composition)
    }
}
