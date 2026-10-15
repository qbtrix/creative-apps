// Fakes/FakeKeyEasing.swift: a small, predictable KeyEasing (#428): lists the
// layer's keys by property then frame and sets an easing on a set of them,
// all or nothing. Linux-safe; never used by `.live`.

public struct FakeKeyEasing: KeyEasing {
    public init() {}
    public func keys(of layerID: String, in composition: HaloComposition) -> [HaloKeyRef] {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else { return [] }
        return HaloProperty.allCases.flatMap { p in
            (layer.tracks[p.rawValue] ?? []).map { HaloKeyRef(layerID: layerID, property: p, frame: $0.frame) }
        }
    }
    public func easing(of key: HaloKeyRef, in composition: HaloComposition) -> HaloEasing? {
        composition.layers.first { $0.id == key.layerID }?.tracks[key.property.rawValue]?.first { $0.frame == key.frame }?.easing
    }
    public func setEasing(_ easing: HaloEasing, on keys: Set<HaloKeyRef>, in composition: inout HaloComposition) throws {
        guard !keys.isEmpty else { throw HaloEditError.noKeySelected }
        var copy = composition
        for key in keys {
            guard let l = copy.layers.firstIndex(where: { $0.id == key.layerID }),
                let k = copy.layers[l].tracks[key.property.rawValue]?.firstIndex(where: { $0.frame == key.frame })
            else { throw HaloEditError.unknownLayer(key.layerID) }
            copy.layers[l].tracks[key.property.rawValue]?[k].easing = easing
        }
        composition = copy
    }
}
