// Live/LiveViewerDragging.swift: the live ViewerDragging (#207). `hit` walks
// the layers top first and returns the first drawn, non-null one whose box
// holds the point mapped back through its world matrix from HaloKeyRules (not
// FrameDrawing, which is viewer-playback's). `commitMove` maps the delta into
// the parent's space and writes x and y through HaloKeyRules.setValue, so an
// animated position gets a key and a static one moves. Linux-safe.

public struct LiveViewerDragging: ViewerDragging {
    public init() {}

    public func hit(_ composition: HaloComposition, at frame: Int, point: HaloPoint) -> String? {
        composition.layers.first { layer in
            guard layer.kind != .null, layer.isVisible(at: frame),
                let world = HaloKeyRules.worldMatrix(of: layer.id, in: composition, at: frame),
                let inverse = try? world.inverted()
            else { return false }
            let local = inverse.apply(point), b = layer.bounds(in: composition)
            return local.x >= b.x && local.x <= b.x + b.width && local.y >= b.y && local.y <= b.y + b.height
        }?.id
    }

    public func commitMove(
        _ layerID: String, by delta: HaloPoint, at frame: Int, in composition: inout HaloComposition
    ) throws {
        guard delta.x != 0 || delta.y != 0 else { return }
        guard let layer = HaloKeyRules.layer(layerID, in: composition) else {
            throw HaloEditError.unknownLayer(layerID)
        }
        let moved = Self.inParentSpace(delta, of: layer, in: composition, at: frame)
        let x = HaloKeyRules.value(.x, of: layer, in: composition, at: frame)
        let y = HaloKeyRules.value(.y, of: layer, in: composition, at: frame)
        var copy = composition
        try HaloKeyRules.setValue(x + moved.x, for: .x, of: layerID, at: frame, in: &copy)
        try HaloKeyRules.setValue(y + moved.y, for: .y, of: layerID, at: frame, in: &copy)
        composition = copy
    }

    /// `delta` (composition pixels) through the inverse of the linear part of
    /// the parent's world matrix: a vector, so the translation drops out. An
    /// unparented layer, or a parent that can't be inverted, keeps `delta`.
    private static func inParentSpace(
        _ delta: HaloPoint, of layer: HaloLayer, in c: HaloComposition, at f: Int
    ) -> HaloPoint {
        guard let parentID = layer.parentID, let world = HaloKeyRules.worldMatrix(of: parentID, in: c, at: f) else {
            return delta
        }
        let linear = HaloMatrix(a: world.a, b: world.b, c: world.c, d: world.d, tx: 0, ty: 0)
        guard let inverse = try? linear.inverted() else { return delta }
        return inverse.apply(delta)
    }
}
