// Live/HaloDrawRules.swift: the one draw-list rule (#37), shared by
// LiveFrameDrawing and FakeFrameDrawing so the two can't drift apart, plus
// the draw list's summary and world boxes the viewer reads. Linux-safe.
import FlareCore

enum HaloDrawRules {
    /// Bottom first; nulls and out-of-span layers left out. A nil matrix or
    /// opacity from `placing` falls back to identity and `layer.opacity`.
    static func drawList(_ c: HaloComposition, at frame: Int, placing: any LayerPlacing) -> HaloDrawList {
        let items = c.layers.reversed().filter { $0.kind != .null && $0.isVisible(at: frame) }.map { layer in
            HaloDrawItem(
                layerID: layer.id, kind: layer.kind, bounds: layer.bounds(in: c),
                matrix: placing.worldMatrix(of: layer.id, in: c, at: frame) ?? .identity,
                opacity: placing.value(.opacity, of: layer.id, in: c, at: frame) ?? layer.opacity,
                color: layer.color, blendMode: layer.blendMode, text: layer.text)
        }
        return HaloDrawList(width: c.width, height: c.height, frame: frame, items: items)
    }
}

extension HaloDrawList {
    /// "3 layers drawn", "1 layer drawn", "No layers drawn": the canvas's value.
    public var drawnSummary: String {
        switch items.count {
        case 0: "No layers drawn"
        case 1: "1 layer drawn"
        default: "\(items.count) layers drawn"
        }
    }

    /// The axis-aligned box, in composition pixels, of the four corners of
    /// `layerID`'s bounds through its matrix; nil when it isn't drawn.
    public func worldBox(of layerID: String) -> HaloLayerRect? {
        guard let item = items.first(where: { $0.layerID == layerID }) else { return nil }
        let b = item.bounds
        let corners = [
            HaloPoint(x: b.x, y: b.y), HaloPoint(x: b.x + b.width, y: b.y),
            HaloPoint(x: b.x, y: b.y + b.height), HaloPoint(x: b.x + b.width, y: b.y + b.height),
        ].map { item.matrix.apply($0) }
        let xs = corners.map(\.x), ys = corners.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
        return HaloLayerRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
