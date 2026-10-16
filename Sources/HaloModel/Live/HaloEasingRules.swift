// Live/HaloEasingRules.swift: the one home of the easing rules (#428), so
// LiveKeyEasing and FakeKeyEasing share them instead of copying them. A
// layer's keys list by property (HaloProperty.allCases) then frame; setting
// an easing is all or nothing: an empty set, a non-finite curve or a key that
// doesn't exist throws and leaves the composition as it was. A custom curve's
// handle x values are clamped to 0...1 (FlareCore's cubic needs them there),
// its y values are kept. Internal; Linux-safe.

enum HaloEasingRules {
    /// Every key of the layer, by property then frame; empty for an unknown layer.
    static func keys(of layerID: String, in c: HaloComposition) -> [HaloKeyRef] {
        guard let layer = c.layers.first(where: { $0.id == layerID }) else { return [] }
        return HaloProperty.allCases.flatMap { p in
            (layer.tracks[p.rawValue] ?? []).map(\.frame).sorted().map {
                HaloKeyRef(layerID: layerID, property: p, frame: $0)
            }
        }
    }

    /// The easing from `key` to the next key; nil when the key doesn't exist.
    static func easing(of key: HaloKeyRef, in c: HaloComposition) -> HaloEasing? {
        c.layers.first { $0.id == key.layerID }?.tracks[key.property.rawValue]?.first { $0.frame == key.frame }?
            .easing
    }

    /// Sets `e` on every key in `keys`, all or nothing.
    static func setEasing(_ e: HaloEasing, on keys: Set<HaloKeyRef>, in c: inout HaloComposition) throws {
        let ordered = keys.sorted(by: inOrder)
        guard let first = ordered.first else { throw HaloEditError.noKeySelected }
        var easing = e
        if case let .cubicBezier(x1, y1, x2, y2) = e {
            guard [x1, y1, x2, y2].allSatisfy(\.isFinite) else { throw HaloEditError.notANumber(first.property) }
            easing = .cubicBezier(x1: min(max(x1, 0), 1), y1: y1, x2: min(max(x2, 0), 1), y2: y2)
        }
        var copy = c
        for key in ordered {
            guard let l = copy.layers.firstIndex(where: { $0.id == key.layerID }),
                let k = copy.layers[l].tracks[key.property.rawValue]?.firstIndex(where: { $0.frame == key.frame })
            else { throw HaloEditError.unknownLayer(key.layerID) }
            copy.layers[l].tracks[key.property.rawValue]?[k].easing = easing
        }
        c = copy
    }

    /// Layer, then property order, then frame: so "the first key" is the same every run.
    private static func inOrder(_ a: HaloKeyRef, _ b: HaloKeyRef) -> Bool {
        if a.layerID != b.layerID { return a.layerID < b.layerID }
        if a.property != b.property { return rank(a.property) < rank(b.property) }
        return a.frame < b.frame
    }

    private static func rank(_ p: HaloProperty) -> Int {
        HaloProperty.allCases.firstIndex(of: p) ?? 0
    }
}
