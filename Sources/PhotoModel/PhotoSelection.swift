// PhotoSelection.swift: what Photo does with the marquee selection and a
// pending crop. Select All covers the canvas and Deselect drops the
// selection. Delete Selection clears the selected pixels of the selected layer
// to transparent and Fill Selection paints them the tool color; each is one
// undo step that keeps only the changed tiles. Apply Crop cuts every layer to
// the pending crop (keeping each layer where it was on screen), makes that the
// canvas size and drops the selection: one undo step that keeps the whole
// stack, since the size changes. The selection is a whole-pixel rectangle.
// ponytail: rectangles only; a CoreRaster Mask once lasso or ellipse arrive.
// Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    public var canSelectAll: Bool { canvas != nil }
    public var canDeselect: Bool { selection != nil }
    /// Delete Selection and Fill Selection need a selection over the selected layer.
    public var canEditSelection: Bool {
        guard let selection, let layer = selectedLayer, let bounds = bounds(of: layer) else { return false }
        return selection.intersection(bounds) != nil
    }
    public var canApplyCrop: Bool { pendingCrop != nil }

    public mutating func selectAll() {
        guard let canvas else { return }
        selection = canvas.rect
    }

    public mutating func deselect() {
        selection = nil
    }

    /// Clears the selected pixels of the selected layer to transparent.
    public mutating func deleteSelection() {
        editSelection(named: "Delete") { _ in .clear }
    }

    /// Fills the selected pixels of the selected layer with the tool color.
    public mutating func fillSelection() {
        let paint = toolOptions.linearColor
        editSelection(named: "Fill") { _ in RGBA(r: paint.r, g: paint.g, b: paint.b, a: 1) }
    }

    /// Cuts every layer to the pending crop and makes it the canvas.
    public mutating func applyCrop() {
        guard let crop = pendingCrop else { return }
        record(.stack(stackState), named: "Crop")
        for (at, layer) in layers.enumerated() {
            guard let buffer = pixels[layer.id], let bounds = bounds(of: layer) else { continue }
            if let kept = bounds.intersection(crop),
                let cut = try? buffer.cropped(
                    x: kept.x - layer.offsetX, y: kept.y - layer.offsetY, width: kept.width, height: kept.height)
            {
                pixels[layer.id] = cut
                layers[at].offsetX = kept.x - crop.x
                layers[at].offsetY = kept.y - crop.y
            } else if let empty = try? PixelBuffer(width: 1, height: 1) {
                // A layer wholly outside the crop keeps one transparent pixel.
                pixels[layer.id] = empty
                layers[at].offsetX = 0
                layers[at].offsetY = 0
            }
        }
        canvas = CanvasSize(width: crop.width, height: crop.height)
        selection = nil
        pendingCrop = nil
        touch(.all)
    }

    public mutating func cancelCrop() {
        pendingCrop = nil
    }

    /// Replaces each selected pixel of the selected layer with `pixel(old)`,
    /// as one undo step named `name`.
    private mutating func editSelection(named name: String, _ pixel: (RGBA) -> RGBA) {
        guard let selection, let id = selectedLayerID, let at = index(of: id), let bounds = bounds(of: layers[at]),
            let area = selection.intersection(bounds), let before = pixels[id]
        else { return }
        var after = before
        let local = area.offsetBy(-layers[at].offsetX, -layers[at].offsetY)
        for y in local.y..<local.maxY {
            for x in local.x..<local.maxX {
                // Inside the layer by construction, and the new pixels are finite.
                if let old = try? before.pixel(x: x, y: y) { try? after.setPixel(x: x, y: y, pixel(old)) }
            }
        }
        guard let diff = try? TileDiff(before: before, after: after), diff.tileCount > 0 else { return }
        record(.pixels(layer: id, diff: diff, forward: false), named: name)
        pixels[id] = after
        touch(.region(area))
    }
}
