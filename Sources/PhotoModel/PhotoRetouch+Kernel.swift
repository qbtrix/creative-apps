// PhotoRetouch+Kernel.swift (fill-heal FH-7): Photo's workspace as
// SuiteImaging's RetouchTarget, so fill.bucket, retouch.spot-heal,
// retouch.heal and retouch.remove run on Photo. The target is the selected
// pixel layer laid on a canvas-sized buffer; All Layers reads the composite;
// the selection is a coverage only when one is set; the bucket paints the
// brush colour; heal's source is the Option-click clone source's offset.
// `replaceTarget` writes back through `editSelection`, weighted by the
// selection like Fill Selection, as one undo step that keeps only the tiles
// it changed. A text layer's pixels come from its words, so it refuses.
// Linux-safe.
import CoreRaster
import SuiteImaging
import SuiteKernel

extension PhotoWorkspace: RetouchTarget {
    static let retouchLayerHelp = "Select an image layer in the sidebar to paint on."
    static let retouchTextHelp = "A text layer's pixels come from its words; select an image layer."

    /// Why nothing can be filled or healed now; nil on a pixel layer of an open image.
    public var retouchHelp: String? {
        guard canvas != nil else { return "Open an image first." }
        guard let layer = selectedLayer, pixels[layer.id] != nil else { return Self.retouchLayerHelp }
        switch layer.kind {
        case .pixels: return nil
        case .adjustment: return Self.retouchLayerHelp
        case .text: return Self.retouchTextHelp
        }
    }

    /// The selected layer's pixels where they sit on the canvas, canvas-sized
    /// (clear where the layer doesn't reach); nil when `retouchHelp` says why.
    public var targetPixels: PixelBuffer? {
        guard retouchHelp == nil, let canvas, let layer = selectedLayer, let tiled = pixels[layer.id],
            let flat = try? tiled.flattened()
        else { return nil }
        if layer.offsetX == 0, layer.offsetY == 0, flat.width == canvas.width, flat.height == canvas.height { return flat }
        guard var placed = try? PixelBuffer(width: canvas.width, height: canvas.height),
            (try? placed.composite(flat, x: layer.offsetX, y: layer.offsetY, mode: .normal, opacity: 1)) != nil
        else { return nil }
        return placed
    }

    /// The picture as seen, for the bucket's All Layers.
    public var mergedPixels: PixelBuffer? { try? composite() }

    /// The selection's coverage on the canvas; nil with nothing selected.
    public var selectionCoverage: Mask? {
        guard let canvas, let selection else { return nil }
        if let selectionMask, selectionMask.width == canvas.width, selectionMask.height == canvas.height { return selectionMask }
        return try? Mask.rectangle(
            width: canvas.width, height: canvas.height, x: Double(selection.x), y: Double(selection.y),
            w: Double(selection.width), h: Double(selection.height))
    }

    /// The brush colour, opaque.
    public var paintColor: RGBA {
        let paint = brushOptions.linearColor
        return RGBA(r: paint.r, g: paint.g, b: paint.b, a: 1)
    }

    /// The clone source's offset from the stroke, once a stroke after the Option-click has fixed it.
    public var cloneOffset: (dx: Int, dy: Int)? {
        cloneSource?.offset.map { (dx: $0.x, dy: $0.y) }
    }

    /// Writes canvas-sized `p` into the selected layer as one undo step named
    /// `name`; nothing is recorded when no pixel changes.
    public mutating func replaceTarget(_ p: PixelBuffer, name: String) throws {
        guard let canvas, p.width == canvas.width, p.height == canvas.height else {
            throw RasterError.invalid("the retouched pixels aren't the canvas's size")
        }
        if let why = retouchHelp { throw RasterError.invalid(why) }
        editSelection(named: name, in: canvas.rect, masked: true) { x, y, old in (try? p.pixel(x: x, y: y)) ?? old }
    }
}
