// PhotoCropSize.swift: the crop tool's drag (PV-3 owns this file). Today the
// rectangle from the press to the pointer is the pending crop (Apply Crop
// commits it), and a click drops it; the modifier keys and zoom arrive for
// PV-3's aspect lock and handles. Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// The crop's drag from the stroke's press to `end`, in canvas pixels.
    mutating func cropDrag(
        _ current: PhotoStroke, to end: Mask.Point, modifiers: DragModifiers, zoom: Double, in canvas: CanvasSize
    ) {
        pendingCrop = Self.dragRect(current.start, end, in: canvas)
    }
}
