// Live/HaloKeyRules.swift: the one home of section 2's rules (where a
// property's value lives, a layer's place through its parents), so the live
// types and the fakes share them instead of copying them. Values sample a
// track with FlareCore's `Timeline.value(of:at:)` and fall back to the
// layer's default (opacity's static home is `HaloLayer.opacity`). Key state,
// the stopwatch and the key diamond decide with SuiteKernel's `KeyRules`
// (AE-h1); opacity's home and the stopwatch's last-frame rule stay here.
// A layer's place through its parents and the parent picker run on the
// kernel's follow link (`LayerTree.worldPlacement`, `follows`, `setFollow`;
// AL-h1).
// Internal; Linux-safe.
import FlareCore
import SuiteKernel

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

    /// Layer space to composition space, parents applied outermost last,
    /// through the kernel's `worldPlacement`. The walk stops at a parent it
    /// has already seen (a cycle) or an unknown one. Nil for an unknown id.
    /// A layer that follows nothing is its own local matrix, the walk's
    /// answer for a root, without building the tree: a frame's draw list
    /// asks for every layer, so a tree per layer cost layers squared (#5844).
    static func worldMatrix(of id: String, in c: HaloComposition, at f: Int) -> HaloMatrix? {
        guard let layer = layer(id, in: c) else { return nil }
        // ponytail: a followed layer still builds the tree per call; build one per draw list if parented comps grow.
        guard layer.parentID != nil else { return localMatrix(of: layer, in: c, at: f) }
        return c.layerTree.worldPlacement(of: id) { localMatrix(of: $0.payload, in: c, at: f) }
    }

    /// Whether `id` follows `ancestorID` through its chain of parents: the
    /// kernel's `follows`, so never for a layer and itself.
    static func follows(_ id: String, _ ancestorID: String, in c: HaloComposition) -> Bool {
        c.layerTree.follows(id, ancestorID)
    }

    /// Section 2's not-animated rule, read side: fewer than two keys is not
    /// animated; otherwise a key at `f` is keyed here, else animated.
    static func keyState(_ track: [HaloKeyframe], at f: Int) -> HaloKeyState {
        HaloKeyState(KeyRules.state(track, at: f))
    }

    /// The TRANSFORM rows of layer `id` at `f`, in `HaloProperty.allCases`
    /// order, then its style rows (layer-styles HY-5); [] for an unknown id.
    static func rows(for id: String, in c: HaloComposition, at f: Int) -> [HaloPropertyRow] {
        guard let layer = layer(id, in: c) else { return [] }
        return (HaloProperty.allCases + layer.styleProperties).map { p in
            let v = value(p, of: layer, in: c, at: f)
            return HaloPropertyRow(
                property: p, value: v, text: p.text(v), keyState: keyState(layer.tracks[p.rawValue] ?? [], at: f))
        }
    }

    /// Section 2's not-animated rule, write side: a finite `v`, clamped to
    /// `p.range`, keys `f` on an animated track (two keys or more) and
    /// otherwise replaces the one static value. Throws `.notANumber(p)` for
    /// NaN or infinity and `.unknownLayer` for an unknown id, changing nothing.
    static func setValue(_ v: Double, for p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws {
        guard v.isFinite else { throw HaloEditError.notANumber(p) }
        let clamped = min(max(v, p.range.lowerBound), p.range.upperBound)
        try change(id, in: &c) { layer in
            let track = layer.tracks[p.rawValue] ?? []
            if track.count >= 2 { layer.tracks[p.rawValue] = keyed(track, frame: f, value: clamped) }
            else { setStatic(clamped, p, of: &layer) }
        }
    }

    /// The stopwatch: an animated `p` goes static at its value at `f`; a
    /// static one gets keys at `f` and at the last frame (frame 0 when `f`
    /// is the last), both holding its value at `f`. Where the kernel refuses
    /// (a one-frame composition) the track becomes one key at `f`.
    static func toggleAnimation(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws {
        let other = f == c.lastFrame ? 0 : c.lastFrame
        try change(id, in: &c, at: f, p) { layer, v in
            var track = layer.tracks[p.rawValue] ?? []
            if !KeyRules.toggleAnimated(&track, at: f, lastFrame: other, value: v) { track = [HaloKeyframe(frame: f, value: v)] }
            if track.isEmpty { setStatic(v, p, of: &layer) } else { layer.tracks[p.rawValue] = track }
        }
    }

    /// The key diamond: removes the key at `f`, or adds one holding the
    /// value at `f`. A track left with fewer than two keys goes static at
    /// its remaining value.
    static func toggleKey(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws {
        try change(id, in: &c, at: f, p) { layer, v in
            var track = layer.tracks[p.rawValue] ?? []
            let staying = track.first { $0.frame != f }?.value
            if !track.contains(where: { $0.frame == f }) { track.sort { $0.frame < $1.frame } }
            _ = KeyRules.toggleKey(&track, at: f, value: v, leaving: .propertyGoesStatic)
            if track.count < 2 { setStatic(staying ?? v, p, of: &layer) }
            else { layer.tracks[p.rawValue] = track }
        }
    }

    /// The parent picker: layer `id` follows `pid` (nil clears it) through
    /// the kernel's `setFollow(keepingPlace:)` and keeps its anchor's place on
    /// screen at `f`, its x and y rewritten in the new parent's space through
    /// `setValue` (keyed when animated). The layer itself, or a layer that
    /// already follows it, throws `.parentCycle(<its name>)`; an unknown id
    /// throws `.unknownLayer`. A refusal changes nothing. Under a parent that
    /// can't be inverted (a scale of 0 squashes every point to one) x and y
    /// stay as they are.
    static func setParent(_ pid: String?, of id: String, at f: Int, in c: inout HaloComposition) throws {
        guard let child = layer(id, in: c) else { throw HaloEditError.unknownLayer(id) }
        let before = c
        let anchor = HaloPoint(x: value(.anchorX, of: child, in: c, at: f), y: value(.anchorY, of: child, in: c, at: f))
        var local: HaloPoint?
        var copy = c
        try copy.editLayerTree { (tree: inout LayerTree<HaloLayer>) throws(TreeRefusal) in
            try tree.setFollow(id, pid, local: { localMatrix(of: $0.payload, in: before, at: f) }) { _, placed in
                local = placed.apply(anchor)
            }
        }
        if let local {
            try setValue(local.x, for: .x, of: id, at: f, in: &copy)
            try setValue(local.y, for: .y, of: id, at: f, in: &copy)
        }
        c = copy
    }

    /// The not-animated home of a value: `opacity` on the layer and a style
    /// property in the layer's style, each with no track; every other
    /// property a one-key track at frame 0.
    private static func setStatic(_ v: Double, _ p: HaloProperty, of layer: inout HaloLayer) {
        if p.styleKind != nil {
            layer.setStyleValue(v, p)
            layer.tracks[p.rawValue] = nil
        } else if p == .opacity {
            layer.opacity = v
            layer.tracks[p.rawValue] = nil
        } else {
            layer.tracks[p.rawValue] = [HaloKeyframe(frame: 0, value: v)]
        }
    }

    /// `track` with a key at `frame` set to `value` (its easing kept), sorted.
    static func keyed(_ track: [HaloKeyframe], frame: Int, value: Double) -> [HaloKeyframe] {
        var t = track.filter { $0.frame != frame }
        t.append(HaloKeyframe(frame: frame, value: value, easing: track.first { $0.frame == frame }?.easing ?? .linear))
        return t.sorted { $0.frame < $1.frame }
    }

    /// Runs `body` on layer `id`, passing `p`'s value at `f` before the change.
    private static func change(
        _ id: String, in c: inout HaloComposition, at f: Int, _ p: HaloProperty,
        _ body: (inout HaloLayer, Double) -> Void
    ) throws {
        guard let found = layer(id, in: c) else { throw HaloEditError.unknownLayer(id) }
        let v = value(p, of: found, in: c, at: f)
        try change(id, in: &c) { body(&$0, v) }
    }

    /// Runs `body` on layer `id`; throws `.unknownLayer` for an unknown id.
    static func change(_ id: String, in c: inout HaloComposition, _ body: (inout HaloLayer) -> Void) throws {
        guard let i = c.layers.firstIndex(where: { $0.id == id }) else { throw HaloEditError.unknownLayer(id) }
        body(&c.layers[i])
    }

    /// Every other layer except those that already follow `id`, in timeline order.
    static func parentCandidates(for id: String, in c: HaloComposition) -> [String] {
        c.layers.map(\.id).filter { $0 != id && !follows($0, id, in: c) }
    }
}
