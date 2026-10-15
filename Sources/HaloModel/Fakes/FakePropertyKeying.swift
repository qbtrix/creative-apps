// Fakes/FakePropertyKeying.swift: a small, predictable PropertyKeying (#38):
// the TRANSFORM rows, typed values, the stopwatch, the key diamond and the
// parent picker, keeping each protocol doc comment's rules. Its rows and
// writes come from LivePropertyKeying (HaloKeyRules), so fake and live can't
// drift; only parenting is its own until the live one lands. Linux-safe;
// never used by `.live`.

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
        guard let layer = composition.layers.first(where: { $0.id == layerID }) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        if let parentID {
            guard composition.layers.contains(where: { $0.id == parentID }) else { throw HaloEditError.unknownLayer(parentID) }
            if parentID == layerID || HaloKeyRules.follows(parentID, layerID, in: composition) {
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
        try HaloKeyRules.change(layerID, in: &copy) { $0.parentID = parentID }
        let parentWorld = parentID.flatMap { placing.worldMatrix(of: $0, in: copy, at: frame) } ?? .identity
        guard let local = try? parentWorld.inverted().apply(onScreen) else { throw HaloEditError.parentCycle(layer.name) }
        try setValue(local.x, for: .x, of: layerID, at: frame, in: &copy)
        try setValue(local.y, for: .y, of: layerID, at: frame, in: &copy)
        composition = copy
    }

}
