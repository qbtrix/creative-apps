// Fakes/FakeKeyEasing.swift: a small, predictable KeyEasing (#428), a thin
// wrapper over HaloEasingRules so the fake and LiveKeyEasing can't drift
// apart. Linux-safe; never used by `.live`.

public struct FakeKeyEasing: KeyEasing {
    public init() {}
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
