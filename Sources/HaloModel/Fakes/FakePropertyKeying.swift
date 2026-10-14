// Fakes/FakePropertyKeying.swift: a small, predictable PropertyKeying (#38):
// the TRANSFORM rows, typed values, the stopwatch, the key diamond and the
// parent picker, keeping each protocol doc comment's rules. Opacity's static
// value lives on the layer, every other property's in a one-key track.
// Linux-safe; never used by `.live`.
import FlareCore

public struct FakePropertyKeying: PropertyKeying {
    public init() {}
    public func rows(for layerID: String, in composition: HaloComposition, at frame: Int) -> [HaloPropertyRow] {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else { return [] }
        let placing = FakeLayerPlacing()
        return HaloProperty.allCases.map { p in
            let value = placing.value(p, of: layerID, in: composition, at: frame) ?? 0
            let track = layer.tracks[p.rawValue] ?? []
            let state: HaloKeyState =
                track.count < 2 ? .notAnimated : track.contains { $0.frame == frame } ? .keyedHere : .animated
            return HaloPropertyRow(property: p, value: value, text: p.text(value), keyState: state)
        }
    }
    public func setValue(
        _ value: Double, for property: HaloProperty, of layerID: String, at frame: Int,
        in composition: inout HaloComposition
    ) throws {
        guard value.isFinite else { throw HaloEditError.notANumber(property) }
        let v = min(max(value, property.range.lowerBound), property.range.upperBound)
        try change(layerID, in: &composition) { layer in
            let track = layer.tracks[property.rawValue] ?? []
            if track.count >= 2 { layer.tracks[property.rawValue] = Self.keyed(track, frame: frame, value: v) }
            else { Self.setStatic(v, property, of: &layer) }
        }
    }
    public func toggleAnimation(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard let v = FakeLayerPlacing().value(property, of: layerID, in: composition, at: frame) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        let last = composition.lastFrame
        try change(layerID, in: &composition) { layer in
            if (layer.tracks[property.rawValue] ?? []).count >= 2 { Self.setStatic(v, property, of: &layer) }
            else {
                layer.tracks[property.rawValue] = Self.keyed(
                    Self.keyed([], frame: frame, value: v), frame: frame == last ? 0 : last, value: v)
            }
        }
    }
    public func toggleKey(
        _ property: HaloProperty, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard let v = FakeLayerPlacing().value(property, of: layerID, in: composition, at: frame) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        try change(layerID, in: &composition) { layer in
            var track = layer.tracks[property.rawValue] ?? []
            if track.contains(where: { $0.frame == frame }) { track.removeAll { $0.frame == frame } }
            else { track = Self.keyed(track, frame: frame, value: v) }
            if track.count < 2 {
                Self.setStatic(track.first?.value ?? v, property, of: &layer)
            } else {
                layer.tracks[property.rawValue] = track
            }
        }
    }
    public func setParent(
        _ parentID: String?, of layerID: String, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        if let parentID {
            guard composition.layers.contains(where: { $0.id == parentID }) else { throw HaloEditError.unknownLayer(parentID) }
            if parentID == layerID || FakeLayerPlacing.follows(parentID, layerID, in: composition) {
                throw HaloEditError.parentCycle(layer.name)
            }
        }
        let placing = FakeLayerPlacing()
        guard let world = placing.worldMatrix(of: layerID, in: composition, at: frame),
            let ax = placing.value(.anchorX, of: layerID, in: composition, at: frame),
            let ay = placing.value(.anchorY, of: layerID, in: composition, at: frame)
        else { throw HaloEditError.unknownLayer(layerID) }
        let onScreen = world.apply(HaloPoint(x: ax, y: ay))
        var copy = composition
        try change(layerID, in: &copy) { $0.parentID = parentID }
        let parentWorld = parentID.flatMap { placing.worldMatrix(of: $0, in: copy, at: frame) } ?? .identity
        guard let local = try? parentWorld.inverted().apply(onScreen) else { throw HaloEditError.parentCycle(layer.name) }
        try setValue(local.x, for: .x, of: layerID, at: frame, in: &copy)
        try setValue(local.y, for: .y, of: layerID, at: frame, in: &copy)
        composition = copy
    }

    /// The not-animated home of a value: `opacity` on the layer, every other
    /// property a one-key track at frame 0.
    static func setStatic(_ value: Double, _ property: HaloProperty, of layer: inout HaloLayer) {
        if property == .opacity {
            layer.opacity = value
            layer.tracks[property.rawValue] = nil
        } else {
            layer.tracks[property.rawValue] = [HaloKeyframe(frame: 0, value: value)]
        }
    }

    /// `track` with a key at `frame` set to `value`, kept sorted.
    static func keyed(_ track: [HaloKeyframe], frame: Int, value: Double) -> [HaloKeyframe] {
        var t = track.filter { $0.frame != frame }
        t.append(HaloKeyframe(frame: frame, value: value, easing: track.first { $0.frame == frame }?.easing ?? .linear))
        return t.sorted { $0.frame < $1.frame }
    }

    func change(_ layerID: String, in composition: inout HaloComposition, _ body: (inout HaloLayer) -> Void) throws {
        guard let i = composition.layers.firstIndex(where: { $0.id == layerID }) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        body(&composition.layers[i])
    }
}

