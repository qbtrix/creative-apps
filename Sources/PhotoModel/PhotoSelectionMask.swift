// PhotoSelectionMask.swift: the marquee's drag (PV-5 owns this file). Today
// the rectangle from the press to the pointer is the selection, and a click
// deselects; the stroke keeps the modifier keys, so PV-5 can make Shift add
// to the selection and Option subtract from it. Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// The marquee's drag from the stroke's press to `end`, in canvas pixels.
    mutating func selectionDrag(
        _ current: inout PhotoStroke, to end: Mask.Point, modifiers: DragModifiers, zoom: Double, in canvas: CanvasSize
    ) {
        current.modifiers = modifiers
        selection = Self.dragRect(current.start, end, in: canvas)
    }
}
