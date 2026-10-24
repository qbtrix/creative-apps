// PhotoSelectionMask.swift: the marquee's drag and the selection's coverage
// (PV-5 owns this file). Today the rectangle from the press to the pointer is
// the selection, and a click deselects; the stroke keeps the modifier keys, so
// PV-5 can make Shift add to the selection and Option subtract from it. Every
// change to the selection (the marquee, Select All, Deselect, Apply Crop) goes
// through `setSelection`, which also sets `selectionMask` and the kernel
// recipe (PhotoArea+Kernel.swift, area-selection AR-10), so Reselect and the
// area commands follow; `showArea` renders a recipe into the selection.
// Paint, Delete and Fill weight each pixel by `selectionCoverage(x:y:)`: the
// mask's coverage when there is one, else 1 inside the rectangle and 0
// outside, and 1 everywhere with no selection; `coverageWeight()` is nil
// then, so paint skips the multiply. Linux-safe.
import CoreRaster
import SuiteImaging
import SuiteKernel

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
    /// rectangle is exact, and its recipe the area's.
    mutating func setSelection(_ rect: PixelRect?, mask: Mask? = nil) {
        selection = rect
        selectionMask = rect == nil ? nil : mask
        var recipe = AreaRecipe.empty
        if let rect { recipe.apply(.shape(.rect(Self.box(rect)), .replace)) }
        area.set(recipe)
    }

    /// Makes `recipe` the area and its coverage at the canvas's size the
    /// selection, the mask's covered bounds as the rectangle (none when it
    /// covers nothing). Throws with no image, or when the mask can't render.
    mutating func showArea(_ recipe: AreaRecipe) throws {
        guard let canvas else { throw RasterError.invalid(Self.noImage) }
        let mask = try AreaMask.mask(recipe, width: canvas.width, height: canvas.height, sources: try wandSources(recipe))
        area.set(recipe)
        selection = mask.coveredBounds.map { PixelRect(x: $0.x, y: $0.y, width: $0.width, height: $0.height) }
        selectionMask = selection == nil ? nil : mask
    }

    /// The selection's closed outlines in canvas pixels, for the ants: the mask's where its coverage crosses half,
    /// else the rectangle's corners; none without a selection.
    public var areaOutline: [[Point]] {
        if selectionMask != nil { return maskOutline }
        guard let selection else { return [] }
        let (x0, y0, x1, y1) = (Double(selection.x), Double(selection.y), Double(selection.maxX), Double(selection.maxY))
        return [[Point(x: x0, y: y0), Point(x: x1, y: y0), Point(x: x1, y: y1), Point(x: x0, y: y1)]]
    }

    /// `mask`'s outline (`AreaMask.outline`); none without a mask or when it can't be traced.
    static func outline(_ mask: Mask?) -> [[Point]] { mask.flatMap { try? AreaMask.outline($0) } ?? [] }

    /// `rect` in the kernel's document space.
    static func box(_ rect: PixelRect) -> Rect {
        Rect(minX: Double(rect.x), minY: Double(rect.y), maxX: Double(rect.maxX), maxY: Double(rect.maxY))
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
