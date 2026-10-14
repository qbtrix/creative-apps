// Fakes/FakeFrameDrawing.swift: a small, predictable FrameDrawing (#37): the
// visible non-null layers bottom first, each placed by FakeLayerPlacing.
// Linux-safe; never used by `.live`.
import FlareCore

public struct FakeFrameDrawing: FrameDrawing {
    public init() {}
    public func drawList(_ composition: HaloComposition, at frame: Int) -> HaloDrawList {
        let placing = FakeLayerPlacing()
        let items = composition.layers.reversed().filter { $0.kind != .null && $0.isVisible(at: frame) }.map { layer in
            HaloDrawItem(
                layerID: layer.id, kind: layer.kind, bounds: layer.bounds(in: composition),
                matrix: placing.worldMatrix(of: layer.id, in: composition, at: frame) ?? .identity,
                opacity: placing.value(.opacity, of: layer.id, in: composition, at: frame) ?? 1,
                color: layer.color, blendMode: layer.blendMode, text: layer.text)
        }
        return HaloDrawList(width: composition.width, height: composition.height, frame: frame, items: items)
    }
}
