// Contracts/SelectionContracts.swift: selections as coverage masks and layer
// masks (PV-5, #421). A selection is a canvas-size CoreRaster Mask; a
// rectangle selection stays pixel-exact (coverage 0 or 1). A layer mask is a
// buffer the layer's size whose gray (red channel) is the coverage, alpha
// always 1, so the brush paints black to hide and white to reveal and tile
// undo keeps its tiles (PhotoHistory's mask-tiles step). Linux-safe.
import CoreRaster

/// What a selection drag draws, in canvas pixels.
public enum SelectionShape: Sendable, Equatable {
    case rectangle(PixelRect)
    case ellipse(PixelRect)
    /// A freehand outline, closed from the last point to the first.
    case lasso([Mask.Point])
}

/// How a new shape meets the selection there is: Shift adds, Option subtracts.
public enum SelectionCombine: Hashable, Sendable {
    case replace, add, subtract

    public init(_ modifiers: DragModifiers) {
        self = modifiers.contains(.shift) ? .add : modifiers.contains(.option) ? .subtract : .replace
    }
}

/// PV-5: build and change the selection.
public protocol SelectionShaping: PhotoUseCase {
    /// The coverage of `shape` on a `canvas`-size mask, antialiased except
    /// for a rectangle. Throws `PhotoRefusal` for a lasso under 3 points.
    func mask(for shape: SelectionShape, canvas: CanvasSize) throws -> Mask
    /// `new` combined into `current`. Nil when nothing is left selected.
    func combine(_ current: Mask?, with new: Mask, _ mode: SelectionCombine) throws -> Mask?
    /// Everything not selected; the whole canvas when `mask` is nil.
    func inverted(_ mask: Mask?, canvas: CanvasSize) throws -> Mask?
    /// The edge softened over `radius` pixels (0...250); 0 returns `mask`.
    func feathered(_ mask: Mask, radius: Double) throws -> Mask
    /// The smallest whole-pixel rect holding every covered pixel; nil when empty.
    func bounds(of mask: Mask) -> PixelRect?
    /// The marching-ants outline: closed polylines along coverage 0.5, in
    /// canvas pixels, for the overlay.
    func outline(of mask: Mask) -> [[Mask.Point]]
}

/// PV-5: layer masks.
public protocol LayerMasking: PhotoUseCase {
    /// A mask for a layer at `layerBounds` (canvas pixels): the selection's
    /// coverage as gray where it overlaps, black elsewhere; all white (reveal all) when
    /// `selection` is nil.
    func mask(from selection: Mask?, layerBounds: PixelRect) throws -> TiledPixels
    /// `pixels` with every alpha multiplied by the mask's gray: Apply Mask.
    func applying(_ mask: TiledPixels, to pixels: TiledPixels) throws -> TiledPixels
    /// `region`, a part of the layer at `origin` in layer pixels, multiplied
    /// by the mask there: what the renderer composites. Equals `region` for
    /// an all-1 mask, bit for bit.
    func masked(_ region: PixelBuffer, at origin: (x: Int, y: Int), by mask: TiledPixels) throws -> PixelBuffer
}

/// The Marquee tool's options.
public enum SelectionShapeKind: String, Hashable, Sendable, CaseIterable {
    case rectangle, ellipse, lasso
}

public struct SelectionOptions: Hashable, Sendable {
    public var shape: SelectionShapeKind
    /// Pixels, 0...250, applied to each new shape.
    public var feather: Double
    public init(shape: SelectionShapeKind = .rectangle, feather: Double = 0) {
        self.shape = shape; self.feather = feather
    }
}
