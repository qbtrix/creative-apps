// Contracts/LayerContracts.swift: adjustment layers (PV-6, #580) and the
// free transform and flips (PV-7). Linux-safe.
import CoreRaster

/// PV-6: an adjustment in the stack changes the layers under it.
public protocol AdjustmentLayering: PhotoUseCase {
    /// The sections an adjustment layer can hold: exposure, levels, curves
    /// and hue/saturation (blur reads neighbours, so it stays whole-image).
    var kinds: [AdjustmentKind] { get }
    /// `below` (the stack composited so far, a region of the canvas) with
    /// `settings`' enabled sections applied, mixed back by `opacity`,
    /// `blendMode` and `mask` (the same region of the layer mask, coverage as gray; nil for
    /// none). With opacity 1, normal blend and no mask, equals
    /// `settings` applied to `below` bit for bit.
    func applying(_ settings: AdjustmentSettings, to below: PixelBuffer, opacity: Double,
                  blendMode: BlendMode, mask: PixelBuffer?) throws -> PixelBuffer
}

/// A handle of the transform box.
public enum TransformHandle: Hashable, Sendable, CaseIterable {
    case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left
    /// Inside the box: move.
    case inside
    /// Just outside a corner: rotate.
    case rotate
}

/// A layer's pending transform: scale about the box's top-left, then turn
/// clockwise about the box's center, then move.
public struct LayerTransform: Hashable, Sendable {
    public var scaleX: Double
    public var scaleY: Double
    public var degrees: Double
    public var dx: Double
    public var dy: Double
    public init(scaleX: Double = 1, scaleY: Double = 1, degrees: Double = 0, dx: Double = 0, dy: Double = 0) {
        self.scaleX = scaleX; self.scaleY = scaleY; self.degrees = degrees; self.dx = dx; self.dy = dy
    }
    public static let identity = LayerTransform()
}

/// Edit > Free Transform in progress on one layer.
public struct TransformDraft: Hashable, Sendable {
    public var layerID: PhotoLayer.ID
    /// The layer's bounds (or the selection's, when one is set) before the transform.
    public var box: PixelRect
    public var transform: LayerTransform
    public init(layerID: PhotoLayer.ID, box: PixelRect, transform: LayerTransform = .identity) {
        self.layerID = layerID; self.box = box; self.transform = transform
    }
}

public enum FlipAxis: Hashable, Sendable {
    case horizontal, vertical
}

/// PV-7: free transform and flips.
public protocol LayerTransforming: PhotoUseCase {
    /// The handle under `point` (canvas pixels) within `tolerance` canvas
    /// pixels (the app passes 6 pt divided by zoom); nil outside the box.
    func handle(at point: Mask.Point, in draft: TransformDraft, tolerance: Double) -> TransformHandle?
    /// `draft` after dragging `handle` from `start` to `point`: a side or
    /// corner scales with the opposite side fixed (Shift keeps the ratio,
    /// Option scales about the center), inside moves, rotate turns (Shift
    /// snaps to 15 degrees). Scale never reaches 0 or flips sign by a drag.
    func dragged(_ draft: TransformDraft, handle: TransformHandle, from start: Mask.Point,
                 to point: Mask.Point, modifiers: DragModifiers) -> TransformDraft
    /// The four box corners after the transform, clockwise from top-left,
    /// for the overlay.
    func corners(of draft: TransformDraft) -> [Mask.Point]
    /// The layer's pixels with the transform applied (lanczos3), placed at
    /// their new bounds. The identity gives back `content` bit for bit.
    func applied(_ draft: TransformDraft, to content: PlacedPixels) throws -> PlacedPixels
    /// `content` mirrored across its own center line, exactly (no filtering);
    /// twice gives back the input bit for bit.
    func flipped(_ content: PlacedPixels, _ axis: FlipAxis) throws -> PlacedPixels
}
