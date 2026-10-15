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
    /// is the last), both holding its value at `f`.
    static func toggleAnimation(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws {
        let last = c.lastFrame
        try change(id, in: &c, at: f, p) { layer, v in
            if (layer.tracks[p.rawValue] ?? []).count >= 2 { setStatic(v, p, of: &layer) }
            else { layer.tracks[p.rawValue] = keyed(keyed([], frame: f, value: v), frame: f == last ? 0 : last, value: v) }
        }
    }

    /// The key diamond: removes the key at `f`, or adds one holding the
    /// value at `f`. A track left with fewer than two keys goes static at
    /// its remaining value.
    static func toggleKey(_ p: HaloProperty, of id: String, at f: Int, in c: inout HaloComposition) throws {
        try change(id, in: &c, at: f, p) { layer, v in
            var track = layer.tracks[p.rawValue] ?? []
            if track.contains(where: { $0.frame == f }) { track.removeAll { $0.frame == f } }
            else { track = keyed(track, frame: f, value: v) }
            if track.count < 2 { setStatic(track.first?.value ?? v, p, of: &layer) }
            else { layer.tracks[p.rawValue] = track }
        }
    }

    /// The parent picker: layer `id` follows `pid` (nil clears it) and keeps
    /// its anchor's place on screen at `f`, its x and y rewritten in the new
    /// parent's space through `setValue` (keyed when animated). The layer
    /// itself, or a layer that already follows it, throws
    /// `.parentCycle(<its name>)`; an unknown id throws `.unknownLayer`. A
    /// refusal changes nothing. Under a parent that can't be inverted (a
    /// scale of 0 squashes every point to one) x and y stay as they are.
    static func setParent(_ pid: String?, of id: String, at f: Int, in c: inout HaloComposition) throws {
        guard let child = layer(id, in: c), let world = worldMatrix(of: id, in: c, at: f) else {
            throw HaloEditError.unknownLayer(id)
        }
        if let pid {
            guard layer(pid, in: c) != nil else { throw HaloEditError.unknownLayer(pid) }
            if pid == id || follows(pid, id, in: c) { throw HaloEditError.parentCycle(child.name) }
        }
        let anchor = HaloPoint(x: value(.anchorX, of: child, in: c, at: f), y: value(.anchorY, of: child, in: c, at: f))
        let screen = world.apply(anchor)
        var copy = c
        try change(id, in: &copy) { $0.parentID = pid }
        let parentWorld = pid.flatMap { worldMatrix(of: $0, in: copy, at: f) } ?? .identity
        if let local = try? parentWorld.inverted().apply(screen) {
            try setValue(local.x, for: .x, of: id, at: f, in: &copy)
            try setValue(local.y, for: .y, of: id, at: f, in: &copy)
        }
        c = copy
    }

    /// The not-animated home of a value: `opacity` on the layer with no
    /// track, every other property a one-key track at frame 0.
    private static func setStatic(_ v: Double, _ p: HaloProperty, of layer: inout HaloLayer) {
        if p == .opacity {
            layer.opacity = v
            layer.tracks[p.rawValue] = nil
        } else {
            layer.tracks[p.rawValue] = [HaloKeyframe(frame: 0, value: v)]
        }
    }

    /// `track` with a key at `frame` set to `value` (its easing kept), sorted.
    private static func keyed(_ track: [HaloKeyframe], frame: Int, value: Double) -> [HaloKeyframe] {
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
