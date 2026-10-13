// PhotoStroke.swift: what each tool does with a drag on the canvas. The canvas
// sends every pointer move as `drag(from:to:)` in canvas pixels (a click is a
// drag that doesn't move) and `endDrag()` when the pointer lifts; one drag is
// one undo step.
//
//   brush, eraser  round dabs along the drag, spaced a quarter of the size
//                  apart, on the selected layer. Each pixel keeps the most
//                  coverage any dab of the stroke gave it, so overlapping dabs
//                  never build past the stroke's opacity. The brush lays the
//                  paint color over the pixels as they were before the stroke;
//                  the eraser scales them (color and alpha) toward transparent.
//                  Undo keeps the changed tiles ("Paint", "Erase").
//   marquee        the rectangle from the press to the pointer is the
//                  selection; a click deselects.
//   crop           the same rectangle is the pending crop (Apply Crop commits
//                  it); a click drops it.
//   move           shifts the selected layer by the drag, in whole pixels
//                  ("Move Layer").
//
// ponytail: dabs write through PixelBuffer.pixel/setPixel one pixel at a time,
// with source-over and the eraser's scaling inline; a CoreRaster dab or
// stamp op is the upgrade once brushes get textures. Linux-safe.
import CoreRaster

/// A drag in progress, from its first `drag` to `endDrag`.
struct PhotoStroke: Sendable, Equatable {
    var tool: PhotoTool
    var start: Mask.Point
    var last: Mask.Point
    /// Brush and eraser: the layer, its pixels before the stroke, each pixel's
    /// coverage so far (row-major, the layer's size), and the distance walked
    /// since the last dab.
    var layerID: PhotoLayer.ID?
    var base: PixelBuffer?
    var coverage: [Float] = []
    var walked: Double = 0
    /// Move: the layer list before the drag.
    var layersBefore: [PhotoLayer] = []
}

extension PhotoWorkspace {
    /// The active tool's drag from `start` to `end`, in canvas pixels.
    public mutating func drag(from start: Mask.Point, to end: Mask.Point) {
        guard let canvas else { return }
        let begun = stroke == nil
        var current = stroke ?? PhotoStroke(tool: tool, start: start, last: start, layerID: selectedLayerID)
        stroke = nil
        switch current.tool {
        case .brush, .eraser:
            paint(&current, to: end, begun: begun)
        case .marquee:
            selection = Self.dragRect(current.start, end, in: canvas)
        case .crop:
            pendingCrop = Self.dragRect(current.start, end, in: canvas)
        case .move:
            if begun { current.layersBefore = layers }
            moveSelectedLayer(current, to: end)
        }
        current.last = end
        stroke = current
    }

    /// Ends the drag: records its undo step, or for a click, clears what a
    /// click clears.
    public mutating func endDrag() {
        guard let done = stroke else { return }
        stroke = nil
        switch done.tool {
        case .brush, .eraser:
            guard let id = done.layerID, let base = done.base, let after = pixels[id],
                let diff = try? TileDiff(before: base, after: after), diff.tileCount > 0
            else { return }
            record(.pixels(layer: id, diff: diff, forward: false), named: done.tool == .brush ? "Paint" : "Erase")
        case .marquee, .crop:
            break
        case .move:
            if done.layersBefore != layers, !done.layersBefore.isEmpty {
                record(.layers(done.layersBefore, selected: selectedLayerID), named: "Move Layer")
            }
        }
    }

    /// The dab centers along `a` to `b`, `spacing` apart, carrying on from
    /// `walked` (the distance since the last dab), and the distance walked
    /// past the last one. A spacing under one pixel counts as one.
    public static func dabCenters(
        from a: Mask.Point, to b: Mask.Point, spacing: Double, walked: Double
    ) -> (centers: [Mask.Point], walked: Double) {
        let step = spacing.isFinite ? max(spacing, 1) : 1
        let dx = b.x - a.x, dy = b.y - a.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length.isFinite, length > 0 else { return ([], walked) }
        var centers: [Mask.Point] = []
        var at = step - min(max(walked, 0), step)
        while at <= length + 1e-9 {
            centers.append(Mask.Point(x: a.x + dx * at / length, y: a.y + dy * at / length))
            at += step
        }
        return (centers, length - (at - step))
    }

    /// A drag's rectangle clipped to the canvas; nil for a click or a drag
    /// that stays outside.
    private static func dragRect(_ a: Mask.Point, _ b: Mask.Point, in canvas: CanvasSize) -> PixelRect? {
        let dx = b.x - a.x, dy = b.y - a.y
        guard dx * dx + dy * dy >= 1 else { return nil }
        return PixelRect(from: a, to: b).intersection(canvas.rect)
    }

    private mutating func moveSelectedLayer(_ current: PhotoStroke, to end: Mask.Point) {
        guard let id = selectedLayerID, let at = index(of: id),
            let before = current.layersBefore.first(where: { $0.id == id })
        else { return }
        let dx = end.x - current.start.x, dy = end.y - current.start.y
        guard dx.isFinite, dy.isFinite, abs(dx) < 1e7, abs(dy) < 1e7 else { return }
        let x = before.offsetX + Int(dx.rounded()), y = before.offsetY + Int(dy.rounded())
        guard x != layers[at].offsetX || y != layers[at].offsetY else { return }
        layers[at].offsetX = x
        layers[at].offsetY = y
        touch(.all)
    }

    /// Lays the dabs from the stroke's last point to `end` (and the first dab,
    /// when the stroke has just begun) on the stroke's layer.
    private mutating func paint(_ current: inout PhotoStroke, to end: Mask.Point, begun: Bool) {
        guard let id = current.layerID, let at = index(of: id), var buffer = pixels.removeValue(forKey: id) else {
            return
        }
        if begun {
            current.base = buffer
            current.coverage = [Float](repeating: 0, count: buffer.width * buffer.height)
        }
        var centers: [Mask.Point] = begun ? [current.start] : []
        let along = Self.dabCenters(
            from: current.last, to: end, spacing: toolOptions.size / 4, walked: begun ? 0 : current.walked)
        centers += along.centers
        current.walked = along.walked
        var touched = PixelRect(x: 0, y: 0, width: 0, height: 0)
        for center in centers {
            // Every index is inside the buffer and every value finite, so a dab can't throw.
            if let area = try? dab(at: center, on: &buffer, layer: layers[at], stroke: &current) {
                touched = touched.union(area)
            }
        }
        pixels[id] = buffer
        if !touched.isEmpty { touch(.region(touched)) }
    }

    /// One dab centered at `center` (canvas pixels). Returns the canvas region
    /// it changed, or nil when it missed the layer.
    private func dab(
        at center: Mask.Point, on buffer: inout PixelBuffer, layer: PhotoLayer, stroke: inout PhotoStroke
    ) throws -> PixelRect? {
        guard let base = stroke.base else { return nil }
        let radius = toolOptions.size / 2
        let cx = center.x - Double(layer.offsetX), cy = center.y - Double(layer.offsetY)
        let box = PixelRect(
            from: Mask.Point(x: cx - radius, y: cy - radius), to: Mask.Point(x: cx + radius, y: cy + radius))
        guard let area = box.intersection(PixelRect(x: 0, y: 0, width: buffer.width, height: buffer.height)) else {
            return nil
        }
        // Coverage falls from 1 to 0 over the soft edge: the outer (1 - hardness)
        // of the radius, and never less than a pixel, so hard edges antialias.
        let softness = max((1 - toolOptions.hardnessPercent / 100) * radius, min(1, radius))
        let opacity = Float(toolOptions.opacityPercent / 100)
        let paint = toolOptions.linearColor
        let erasing = stroke.tool == .eraser
        for y in area.y..<area.maxY {
            for x in area.x..<area.maxX {
                let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                let t = min(max((radius - (dx * dx + dy * dy).squareRoot()) / softness, 0), 1)
                let coverage = Float(t * t * (3 - 2 * t))
                let i = y * buffer.width + x
                guard coverage > stroke.coverage[i] else { continue }
                stroke.coverage[i] = coverage
                let a = coverage * opacity, keep = 1 - coverage * opacity
                let p = try base.pixel(x: x, y: y)
                let out = erasing
                    ? RGBA(r: p.r * keep, g: p.g * keep, b: p.b * keep, a: p.a * keep)
                    : RGBA(r: paint.r * a + p.r * keep, g: paint.g * a + p.g * keep, b: paint.b * a + p.b * keep,
                           a: a + p.a * keep)
                try buffer.setPixel(x: x, y: y, out)
            }
        }
        return area.offsetBy(layer.offsetX, layer.offsetY)
    }
}
