// PhotoMask.swift: layer masks (PV-5). For now only the geometry hook: every
// change to a layer's size or place (crop, Image Size, rotate, straighten,
// delete, and PV-2's and PV-7's own edits) calls `layerGeometryChanged`, so
// PV-5 can keep each mask the size and place of its layer. Its body is empty
// until then, apart from the counting test hook. Linux-safe.
import CoreRaster

/// A geometry change every layer's extras (its mask) must follow.
public enum LayerGeometryChange: Hashable, Sendable {
    case cropped(PixelRect)
    case resized(scaleX: Double, scaleY: Double)
    case rotated(QuarterTurn)
    case straightened(degrees: Double, crop: PixelRect)
    case flippedCanvas(FlipAxis)
    case transformed(LayerTransform)
    case flipped(FlipAxis)
    case duplicated(from: PhotoLayer.ID)
    case removed
}

extension PhotoWorkspace {
    /// Layer `id`'s geometry changed by `change`; PV-5 moves its mask along.
    mutating func layerGeometryChanged(_ id: PhotoLayer.ID, _ change: LayerGeometryChange) {
        geometryChangeCount += 1
        lastGeometryChange = (id, change)
    }
}
