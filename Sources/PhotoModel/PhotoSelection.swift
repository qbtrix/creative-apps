// PhotoSelection.swift: what Photo does with the marquee selection and a
// pending crop. Select All covers the canvas and Deselect drops the
// selection, both through `setSelection` (PhotoSelectionMask.swift), which
// clears the selection mask too. Delete Selection clears the selected pixels
// of the selected layer to transparent and Fill Selection paints them the tool
// color, each pixel weighted by `selectionCoverage`; each is one undo step
// that keeps only the changed tiles. Apply Crop cuts every layer to the
// pending crop (keeping each layer where it was on screen), tells each layer's
// extras through `layerGeometryChanged`, makes that the canvas size and drops
// the selection: one undo step that keeps the whole stack, since the size
// changes. The selection is a whole-pixel rectangle.
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
    /// A pending crop that covers the whole canvas would change nothing.
    public var canApplyCrop: Bool { pendingCrop != nil && pendingCrop != canvas?.rect }

    public mutating func selectAll() {
        guard let canvas else { return }
        setSelection(canvas.rect)
    }

    public mutating func deselect() {
        setSelection(nil)
    }

    /// Clears the selected pixels of the selected layer to transparent.
    public mutating func deleteSelection() {
        editSelection(named: "Delete") { _ in .clear }
    }

    /// Fills the selected pixels of the selected layer with the brush color.
    public mutating func fillSelection() {
        let paint = brushOptions.linearColor
        editSelection(named: "Fill") { _ in RGBA(r: paint.r, g: paint.g, b: paint.b, a: 1) }
    }

    /// Cuts every layer to the pending crop and makes it the canvas.
    public mutating func applyCrop() {
        guard canApplyCrop, let crop = pendingCrop else { return }
        record(.stack(stackState), named: "Crop")
        for (at, layer) in layers.enumerated() {
            layerGeometryChanged(layer.id, .cropped(crop))
            guard let tiled = pixels[layer.id], let bounds = bounds(of: layer) else { continue }
            if let kept = bounds.intersection(crop),
                let cut = try? tiled.flattened().cropped(
                    x: kept.x - layer.offsetX, y: kept.y - layer.offsetY, width: kept.width, height: kept.height)
            {
                pixels[layer.id] = TiledPixels(cut)
                layers[at].offsetX = kept.x - crop.x
                layers[at].offsetY = kept.y - crop.y
            } else if let empty = try? TiledPixels(width: 1, height: 1) {
                // A layer wholly outside the crop keeps one transparent pixel.
                pixels[layer.id] = empty
                layers[at].offsetX = 0
                layers[at].offsetY = 0
            }
        }
        canvas = CanvasSize(width: crop.width, height: crop.height)
        setSelection(nil)
        pendingCrop = nil
        touch(.all)
    }

    public mutating func cancelCrop() {
        pendingCrop = nil
    }

    /// Replaces each selected pixel of the selected layer with `pixel(old)`,
    /// weighted by the selection's coverage there, as one undo step named
    /// `name` that keeps the tiles it changed.
    mutating func editSelection(named name: String, _ pixel: (RGBA) -> RGBA) {
        guard let selection, let id = selectedLayerID, let at = index(of: id), let bounds = bounds(of: layers[at]),
            let area = selection.intersection(bounds), var tiled = pixels[id]
        else { return }
        let local = area.offsetBy(-layers[at].offsetX, -layers[at].offsetY)
        let weight = coverageWeight(offsetX: layers[at].offsetX, offsetY: layers[at].offsetY)
        var before: [Int: PixelBuffer] = [:]
        for i in tiled.tileIndices(in: local) where tiled.tiles.indices.contains(i) {
            let rect = tiled.tileRect(i), old = tiled.tiles[i]
            guard let part = local.intersection(rect) else { continue }
            for y in (part.y - rect.y)..<(part.maxY - rect.y) {
                for x in (part.x - rect.x)..<(part.maxX - rect.x) {
                    // Inside the tile by construction, and the new pixels are finite.
                    guard let p = try? old.pixel(x: x, y: y) else { continue }
                    let w = weight?(rect.x + x, rect.y + y) ?? 1
                    try? tiled.tiles[i].setPixel(x: x, y: y, w >= 1 ? pixel(p) : Self.mix(p, pixel(p), w))
                }
            }
            if tiled.tiles[i] != old { before[i] = old }
        }
        guard !before.isEmpty else { return }
        record(.tiles(layer: id, before), named: name)
        pixels[id] = tiled
        touch(.region(area))
    }

    /// `old` moved toward `new` by `w` (0 keeps `old`, 1 gives `new`).
    static func mix(_ old: RGBA, _ new: RGBA, _ w: Float) -> RGBA {
        let k = min(max(w, 0), 1)
        return RGBA(
            r: old.r + (new.r - old.r) * k, g: old.g + (new.g - old.g) * k, b: old.b + (new.b - old.b) * k,
            a: old.a + (new.a - old.a) * k)
    }
}
