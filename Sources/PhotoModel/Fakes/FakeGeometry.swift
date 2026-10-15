// Fakes/FakeGeometry.swift: the geometry fakes (blueprint 5.2): crop (PV-3),
// selection and layer masks (PV-5), adjustment layers (PV-6) and the free
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

/// Every shape selects its bounding rectangle.
public struct FakeSelection: SelectionShaping {
    public var unavailableHelp: String? { nil }
    public init() {}
    public func mask(for shape: SelectionShape, canvas: CanvasSize) throws -> Mask {
        let rect: PixelRect
        switch shape {
        case .rectangle(let r), .ellipse(let r): rect = r
        case .lasso(let points):
            guard let first = points.first else { throw PhotoRefusal("Draw around the area to select.") }
            rect = points.reduce(PixelRect(from: first, to: first)) { $0.union(PixelRect(from: $1, to: $1)) }
        }
        return try Mask.rectangle(width: canvas.width, height: canvas.height, x: Double(rect.x), y: Double(rect.y),
                                  w: Double(rect.width), h: Double(rect.height))
    }
    public func combine(_ current: Mask?, with new: Mask, _ mode: SelectionCombine) throws -> Mask? {
        guard var current, mode != .replace else { return mode == .subtract ? current : new }
        if mode == .add { try current.add(new) } else { try current.subtract(new) }
        return current
    }
    public func inverted(_ mask: Mask?, canvas: CanvasSize) throws -> Mask? {
        guard var mask else { return try Mask(width: canvas.width, height: canvas.height, fill: 1) }
        mask.invert()
        return mask
    }
    public func feathered(_ mask: Mask, radius: Double) throws -> Mask { mask }
    public func bounds(of mask: Mask) -> PixelRect? {
        mask.area > 0 ? PixelRect(x: 0, y: 0, width: mask.width, height: mask.height) : nil
    }
    public func outline(of mask: Mask) -> [[Mask.Point]] {
        guard let b = bounds(of: mask) else { return [] }
        let (x0, y0, x1, y1) = (Double(b.x), Double(b.y), Double(b.maxX), Double(b.maxY))
        return [[.init(x: x0, y: y0), .init(x: x1, y: y0), .init(x: x1, y: y1), .init(x: x0, y: y1)]]
    }
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
}
