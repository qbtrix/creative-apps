// Fakes/FakeViewerDragging.swift: a small, predictable ViewerDragging (#207):
// hits the topmost drawn layer's box and commits a move through
// FakePropertyKeying, so an animated position gets a key. A zero delta
// changes nothing. Linux-safe; never used by `.live`.

public struct FakeViewerDragging: ViewerDragging {
    public init() {}
    public func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String? {
        for item in FakeFrameDrawing().drawList(composition, at: frame).items.reversed() {
            guard let local = try? item.matrix.inverted().apply(point) else { continue }
            let b = item.bounds
            if local.x >= b.x, local.x <= b.x + b.width, local.y >= b.y, local.y <= b.y + b.height { return item.layerID }
        }
        return nil
    }
    public func commitMove(
        _ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard delta.x != 0 || delta.y != 0 else { return }
        let placing = FakeLayerPlacing(), keying = FakePropertyKeying()
        guard let layer = composition.layers.first(where: { $0.id == layerID }),
            let x = placing.value(.x, of: layerID, in: composition, at: frame),
            let y = placing.value(.y, of: layerID, in: composition, at: frame)
        else { throw HaloEditError.unknownLayer(layerID) }
        // The delta is in composition space; a parented layer moves in its parent's.
        let parentWorld = layer.parentID.flatMap { placing.worldMatrix(of: $0, in: composition, at: frame) } ?? .identity
        let inverse = (try? parentWorld.inverted()) ?? .identity
        let origin = inverse.apply(HaloPoint(x: 0, y: 0)), moved = inverse.apply(delta)
        var copy = composition
        try keying.setValue(x + moved.x - origin.x, for: .x, of: layerID, at: frame, in: &copy)
        try keying.setValue(y + moved.y - origin.y, for: .y, of: layerID, at: frame, in: &copy)
        composition = copy
    }
}
