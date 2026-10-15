// PhotoSelectionMask.swift: the marquee's drag and the selection's coverage
// (PV-5 owns this file). Today the rectangle from the press to the pointer is
// the selection, and a click deselects; the stroke keeps the modifier keys, so
// PV-5 can make Shift add to the selection and Option subtract from it. Every
// change to the selection (the marquee, Select All, Deselect, Apply Crop) goes
// through `setSelection`, which also sets `selectionMask`. Paint, Delete and
// Fill weight each pixel by `selectionCoverage(x:y:)`: the mask's coverage
// when there is one, else 1 inside the rectangle and 0 outside, and 1
// everywhere with no selection; `coverageWeight()` is nil then, so paint
// skips the multiply. Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// Test hook: while set (`$forcedCoverage.withValue`), the coverage of
    /// every canvas pixel, in place of the selection's.
    @TaskLocal static var forcedCoverage: (@Sendable (Int, Int) -> Float)?

    /// The marquee's drag from the stroke's press to `end`, in canvas pixels.
    mutating func selectionDrag(
        _ current: inout PhotoStroke, to end: Mask.Point, modifiers: DragModifiers, zoom: Double, in canvas: CanvasSize
    ) {
        current.modifiers = modifiers
        setSelection(Self.dragRect(current.start, end, in: canvas))
    }

    /// Makes `rect` the selection (nil: none), with no coverage mask, so the
    /// rectangle is exact.
    mutating func setSelection(_ rect: PixelRect?, mask: Mask? = nil) {
        selection = rect
        selectionMask = rect == nil ? nil : mask
    }

    /// How much of canvas pixel (`x`, `y`) the selection covers, 0...1.
    func selectionCoverage(x: Int, y: Int) -> Float {
        if let forced = Self.forcedCoverage { return forced(x, y) }
        if let selectionMask { return (try? selectionMask.coverage(x: x, y: y)) ?? 0 }
        guard let selection else { return 1 }
        return x >= selection.x && x < selection.maxX && y >= selection.y && y < selection.maxY ? 1 : 0
    }

    /// `selectionCoverage` with the layer's offset added (layer pixels in,
    /// coverage out); nil when every pixel is covered, so a caller skips the
    /// per-pixel weight.
    func coverageWeight(offsetX: Int, offsetY: Int) -> ((Int, Int) -> Float)? {
        guard Self.forcedCoverage != nil || selection != nil || selectionMask != nil else { return nil }
        return { x, y in selectionCoverage(x: x + offsetX, y: y + offsetY) }
    }
}
