// Fakes/FakeGeometry.swift: the geometry fakes (blueprint 5.2): crop (PV-3),
// layer masks (PV-5), adjustment layers (PV-6) and the free
// transform (PV-7). Deterministic and stateless; each does the least that
// still changes something a journey can see. Linux-safe.
import CoreRaster

/// Free aspect only; numbers clamp to the canvas.
public struct FakeCrop: CropSizing {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func setting(_ field: CropField, to value: Int, in crop: PixelRect, aspect: CropAspect,
                        canvas: CanvasSize) -> PixelRect {
        var r = crop
        switch field {
        case .x: r.x = value
        case .y: r.y = value
        case .width: r.width = value
        case .height: r.height = value
        }
        return r.intersection(canvas.rect) ?? crop
    }
    public func dragged(from anchor: Mask.Point, to point: Mask.Point, aspect: CropAspect, canvas: CanvasSize)
        -> PixelRect
    {
        PixelRect(from: anchor, to: point).intersection(canvas.rect) ?? canvas.rect
    }
    public func applying(_ aspect: CropAspect, to crop: PixelRect?, canvas: CanvasSize) -> PixelRect {
        crop ?? canvas.rect
    }
    public func swapped(_ aspect: CropAspect, canvas: CanvasSize) -> CropAspect { aspect }
}

/// Masks reveal everything; nothing is hidden.
public struct FakeMasking: LayerMasking {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func mask(from selection: Mask?, layerBounds: PixelRect) throws -> TiledPixels {
        try TiledPixels(width: layerBounds.width, height: layerBounds.height, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
    }
    public func applying(_ mask: TiledPixels, to pixels: TiledPixels) throws -> TiledPixels { pixels }
    public func masked(_ region: PixelBuffer, at origin: (x: Int, y: Int), by mask: TiledPixels) throws
        -> PixelBuffer
    { region }
}

/// An adjustment layer brightens by one stop, whatever its settings.
public struct FakeAdjustmentLayers: AdjustmentLayering {
    public var unavailableHelp: String? { nil }
    public var kinds: [AdjustmentKind] { [.exposure, .levels, .curves, .hueSaturation] }
    public init() {}
    public func applying(_ settings: AdjustmentSettings, to below: PixelBuffer, opacity: Double,
                         blendMode: BlendMode, mask: PixelBuffer?) throws -> PixelBuffer {
        try below.exposure(stops: 1)
    }
}

/// Only moves: any handle drag translates the box; applying moves the pixels.
public struct FakeTransform: LayerTransforming {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func handle(at point: Mask.Point, in draft: TransformDraft, tolerance: Double) -> TransformHandle? {
        .inside
    }
    public func dragged(_ draft: TransformDraft, handle: TransformHandle, from start: Mask.Point,
                        to point: Mask.Point, modifiers: DragModifiers) -> TransformDraft {
        var next = draft
        next.transform.dx += point.x - start.x
        next.transform.dy += point.y - start.y
        return next
    }
    public func corners(of draft: TransformDraft) -> [Mask.Point] {
        let b = draft.box, t = draft.transform
        let (x0, y0) = (Double(b.x) + t.dx, Double(b.y) + t.dy)
        let (x1, y1) = (x0 + Double(b.width), y0 + Double(b.height))
        return [.init(x: x0, y: y0), .init(x: x1, y: y0), .init(x: x1, y: y1), .init(x: x0, y: y1)]
    }
    public func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels {
        let t = draft.transform
        guard t.dx.isFinite, t.dy.isFinite, abs(t.dx) < 1e6, abs(t.dy) < 1e6 else { return content }
        return PlacedPixels(pixels: content.pixels, x: content.x + Int(t.dx.rounded()),
                            y: content.y + Int(t.dy.rounded()))
    }
    public func flipped(_ content: PlacedPixels, _ axis: FlipAxis) throws -> PlacedPixels { content }
    /// The move `applied` makes, as a matrix.
    public func matrix(_ draft: TransformDraft, origin: (x: Int, y: Int)) throws -> AffineMatrix {
        let t = draft.transform
        let (dx, dy) = t.dx.isFinite && t.dy.isFinite && abs(t.dx) < 1e6 && abs(t.dy) < 1e6 ? (t.dx.rounded(), t.dy.rounded()) : (0, 0)
        return AffineMatrix(a: 1, b: 0, c: 0, d: 1, tx: Double(origin.x) + dx, ty: Double(origin.y) + dy)
    }
}
