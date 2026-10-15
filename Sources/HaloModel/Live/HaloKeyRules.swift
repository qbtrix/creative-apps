// Live/HaloKeyRules.swift: the one home of section 2's rules (where a
// property's value lives, a layer's place through its parents), so the live
// types and the fakes share them instead of copying them. Values sample a
// track with FlareCore's `Timeline.value(of:at:)` and fall back to the
// layer's default (opacity's static home is `HaloLayer.opacity`). Internal;
// Linux-safe.
import FlareCore

enum HaloKeyRules {
    /// The layer `id` names in `c`; nil for an unknown id.
    static func layer(_ id: String, in c: HaloComposition) -> HaloLayer? {
        c.layers.first { $0.id == id }
    }

    /// `p` at frame `f`: its track sampled by FlareCore, or the layer's default with no track.
    static func value(_ p: HaloProperty, of layer: HaloLayer, in c: HaloComposition, at f: Int) -> Double {
        if let track = layer.tracks[p.rawValue], let v = Timeline.value(of: track, at: Double(f)) { return v }
        return layer.defaultValue(p, in: c)
    }

    /// Layer space to its parent's: T(x, y) · R(rotation) · S(scaleX, scaleY) · T(−anchorX, −anchorY).
    static func localMatrix(of layer: HaloLayer, in c: HaloComposition, at f: Int) -> HaloMatrix {
        func v(_ p: HaloProperty) -> Double { value(p, of: layer, in: c, at: f) }
        return HaloMatrix.translation(x: v(.x), y: v(.y)) * HaloMatrix.rotation(degrees: v(.rotation))
            * HaloMatrix.scale(x: v(.scaleX), y: v(.scaleY)) * HaloMatrix.translation(x: -v(.anchorX), y: -v(.anchorY))
    }

    /// Layer space to composition space, parents applied outermost last. The
    /// walk stops at a parent it has already seen (a cycle) or an unknown
    /// one. Nil for an unknown id.
    static func worldMatrix(of id: String, in c: HaloComposition, at f: Int) -> HaloMatrix? {
        guard let start = layer(id, in: c) else { return nil }
        var matrix = localMatrix(of: start, in: c, at: f)
        var seen: Set<String> = [id]
        var next = start.parentID
        while let parentID = next, seen.insert(parentID).inserted, let parent = layer(parentID, in: c) {
            matrix = localMatrix(of: parent, in: c, at: f) * matrix
            next = parent.parentID
        }
        return matrix
    }

    /// Whether `id` follows `ancestorID` through its chain of parents.
    static func follows(_ id: String, _ ancestorID: String, in c: HaloComposition) -> Bool {
        var seen: Set<String> = []
        var next = layer(id, in: c)?.parentID
        while let parentID = next, seen.insert(parentID).inserted {
            if parentID == ancestorID { return true }
            next = layer(parentID, in: c)?.parentID
        }
        return false
    }

    /// Section 2's not-animated rule, read side: fewer than two keys is not
    /// animated; otherwise a key at `f` is keyed here, else animated.
    static func keyState(_ track: [HaloKeyframe], at f: Int) -> HaloKeyState {
        if track.count < 2 { return .notAnimated }
        return track.contains { $0.frame == f } ? .keyedHere : .animated
    }

    /// The TRANSFORM rows of layer `id` at `f`, in `HaloProperty.allCases`
    /// order; [] for an unknown id.
    static func rows(for id: String, in c: HaloComposition, at f: Int) -> [HaloPropertyRow] {
        guard let layer = layer(id, in: c) else { return [] }
        return HaloProperty.allCases.map { p in
            let v = value(p, of: layer, in: c, at: f)
            return HaloPropertyRow(
                property: p, value: v, text: p.text(v), keyState: keyState(layer.tracks[p.rawValue] ?? [], at: f))
        }
    }

    /// Every other layer except those that already follow `id`, in timeline order.
    static func parentCandidates(for id: String, in c: HaloComposition) -> [String] {
        c.layers.map(\.id).filter { $0 != id && !follows($0, id, in: c) }
    }
}
