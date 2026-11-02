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

    /// Heal's release: takes back the clone preview the drag laid, then runs
    /// `retouch.heal` along the stroke as one undo step "Heal". Only the part
    /// of the stroke whose source lies on the canvas heals; a heal that can't
    /// run leaves the layer as it was and says why.
    mutating func healStroke(_ done: PhotoStroke) {
        if let id = done.layerID, var tiled = pixels[id], let layer = layers.first(where: { $0.id == id }) {
            var damage = PixelRect(x: 0, y: 0, width: 0, height: 0)
            for (i, tile) in done.before where tiled.tiles.indices.contains(i) {
                tiled.tiles[i] = tile
                damage = damage.union(tiled.tileRect(i).offsetBy(layer.offsetX, layer.offsetY))
            }
            pixels[id] = tiled
            if !damage.isEmpty { touch(.region(damage)) }
        }
        guard let canvas, let offset = cloneOffset else { return }
        let size = min(max(brushOptions.size, 1), 500)
        let points = Self.healPath(done.path, radius: size / 2, offset: offset, canvas: canvas)
        guard !points.isEmpty else {
            statusMessage = "The source is off the image there; Option-click a nearer source."
            return
        }
        let params = JSONValue.object([
            "points": .array(points.map { .object(["x": .number($0.x), "y": .number($0.y)]) }),
            "size": .number(size), "hardness": .number(brushOptions.hardnessPercent),
        ])
        do { _ = try Self.catalog.run("retouch.heal", params: params, on: &self) } catch {
            if case .unavailable(_, let why) = error { statusMessage = why } else { statusMessage = "Couldn't heal there." }
        }
    }

    /// `path` resampled about a pixel apart, keeping the points whose dab
    /// (`radius`, plus a pixel of soft edge), clipped to the canvas, reads
    /// every source pixel `offset` away on the canvas, so `retouch.heal`
    /// never meets a source off the image.
    static func healPath(_ path: [Mask.Point], radius: Double, offset: (dx: Int, dy: Int), canvas: CanvasSize) -> [Mask.Point] {
        let reach = radius + 1
        func fits(_ p: Mask.Point) -> Bool {
            let x0 = max(0, p.x - reach), x1 = min(Double(canvas.width), p.x + reach)
            let y0 = max(0, p.y - reach), y1 = min(Double(canvas.height), p.y + reach)
            return x0 + Double(offset.dx) >= 0 && x1 + Double(offset.dx) <= Double(canvas.width)
                && y0 + Double(offset.dy) >= 0 && y1 + Double(offset.dy) <= Double(canvas.height)
        }
        let path = path.filter { $0.x.isFinite && $0.y.isFinite && abs($0.x) < 1e7 && abs($0.y) < 1e7 }
        var dense = Array(path.prefix(1))
        for (a, b) in zip(path, path.dropFirst()) {
            let length = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
            let steps = Int(min(max(length.rounded(.up), 1), 10_000))
            dense += (1...steps).map { i in
                let t = Double(i) / Double(steps)
                return Mask.Point(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
            }
        }
        return Array(dense.filter(fits).prefix(100_000))
    }
}
