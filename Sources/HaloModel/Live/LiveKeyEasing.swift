// Live/LiveKeyEasing.swift: the W0 stub of KeyEasing. It lists no keys and
// setting an easing throws `.notBuilt`; the easing feature (#428) replaces
// this file whole with the live type. Linux-safe.

public struct LiveKeyEasing: KeyEasing {
    public init() {}
    public var unavailableHelp: String? { "Easing arrives with #428." }
    public func keys(of layerID: String, in composition: HaloComposition) -> [HaloKeyRef] { [] }
    public func easing(of key: HaloKeyRef, in composition: HaloComposition) -> HaloEasing? { nil }
    public func setEasing(_ easing: HaloEasing, on keys: Set<HaloKeyRef>, in composition: inout HaloComposition) throws {
        throw HaloEditError.notBuilt("Easing")
    }
}
