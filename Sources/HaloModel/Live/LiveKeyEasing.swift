// Live/LiveKeyEasing.swift: the live KeyEasing (#428). Keys are eased with
// FlareCore's `Easing`, which `Timeline.value(of:at:)` samples; listing and
// setting go through HaloEasingRules, the rules the fake shares (all or
// nothing, finite curves only, handle x clamped to 0...1). Linux-safe.

public struct LiveKeyEasing: KeyEasing {
    public init() {}
    public var unavailableHelp: String? { nil }
    public func keys(of layerID: String, in composition: HaloComposition) -> [HaloKeyRef] {
        HaloEasingRules.keys(of: layerID, in: composition)
    }
    public func easing(of key: HaloKeyRef, in composition: HaloComposition) -> HaloEasing? {
        HaloEasingRules.easing(of: key, in: composition)
    }
    public func setEasing(_ easing: HaloEasing, on keys: Set<HaloKeyRef>, in composition: inout HaloComposition) throws {
        try HaloEasingRules.setEasing(easing, on: keys, in: &composition)
    }
}
