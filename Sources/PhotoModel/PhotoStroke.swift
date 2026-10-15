// PhotoStroke.swift: what each tool does with a drag on the canvas. The canvas
// sends every pointer move as `drag(from:to:pressure:)` in canvas pixels (a
// click is a drag that doesn't move), or a display frame's moves at once as
// `drags(_:)`, one revision for all of them, and `endDrag()` when the pointer
// lifts; one drag is one undo step.
//
//   brush, eraser  a round stroke through the pointer samples on the selected
//                  layer: a centripetal Catmull-Rom curve, so sparse samples
//                  from a fast hand still paint a curve. A segment is painted
//                  once the sample after it arrives (the last one on mouse-up),
//                  cut into pieces flat to a quarter pixel, each a capsule
//                  whose width follows the pressure (size x pressure), so the
//                  edge is continuous, never scalloped. Each pixel keeps the
//                  most coverage the stroke gave it, so overlaps never build
//                  past the stroke's opacity. The brush lays the paint color
//                  over the pixels as they were before the stroke; the eraser
//                  scales them (color and alpha) toward transparent. Undo keeps
//                  the tiles the stroke painted, as they were, so no event
//                  walks the whole layer ("Paint", "Erase").
//   clone          with Option held at the press (`sampling`), or with no
//                  source yet, the press samples the clone source and the
//                  drag paints nothing; otherwise clone dabs (PhotoRetouch)
//                  at the brush's size along the pointer samples on the
//                  selected layer, one undo step ("Clone").
//   heal           the same as clone, but each dab takes its tone from where
//                  it lands (PhotoRetouch), one undo step ("Heal").
//   marquee        the rectangle from the press to the pointer is the
//                  selection; a click deselects.
//   crop           the same rectangle is the pending crop (Apply Crop commits
//                  it); a click drops it.
//   move           shifts the selected layer by the drag, in whole pixels
//                  ("Move Layer").
//
// ponytail: capsules write through PixelBuffer.pixel/setPixel one pixel at a
// time, with source-over and the eraser's scaling inline, and visit each
// piece's whole box, so very large brushes on tight curves cost more; a
// CoreRaster stamp op is the upgrade once brushes get textures. Linux-safe.
import CoreRaster

/// A drag in progress, from its first `drag` to `endDrag`.
struct PhotoStroke: Sendable, Equatable {
    var tool: PhotoTool
    var start: Mask.Point
    /// Brush, eraser and clone: the layer; by tile index, each painted tile as it
    /// was before the stroke and its pixels' coverage so far (row-major, the
    /// tile's size); and the last four pointer samples and their pressures.
    var layerID: PhotoLayer.ID?
    var before: [Int: PixelBuffer] = [:]
    var coverage: [Int: [Float]] = [:]
    var samples: [Sample] = []
    /// Move: the layer list before the drag.
    var layersBefore: [PhotoLayer] = []

    struct Sample: Sendable, Equatable {
        var point: Mask.Point
        var pressure: Double
    }
}

extension PhotoWorkspace {
    /// The active tool's drag from `start` to `end`, in canvas pixels.
    /// `pressure` (0...1, a tablet's; a mouse sends 1) scales the brush.
    /// `sampling` (Option held) makes the clone tool's press sample its source.
    public mutating func drag(
        from start: Mask.Point, to end: Mask.Point, pressure: Double = 1, sampling: Bool = false
    ) {
        guard let canvas else { return }
        let begun = stroke == nil
        var current = stroke ?? PhotoStroke(tool: tool, start: start, layerID: selectedLayerID)
        stroke = nil
        switch current.tool {
        case .brush, .eraser:
            if begun { paint(&current, adding: start, pressure: pressure) }
            paint(&current, adding: end, pressure: pressure)
        case .clone, .heal:
            if begun, sampling || cloneSource == nil {
                setCloneSource(at: start)
                current.layerID = nil
            } else if let id = current.layerID {
                let from = current.samples.last?.point ?? start
                current.samples = [PhotoStroke.Sample(point: end, pressure: 1)]
                stamp(
                    along: [from, end], size: brushOptions.size, layer: id, before: &current.before,
                    coverage: &current.coverage, healing: current.tool == .heal)
            }
        case .marquee:
            selection = Self.dragRect(current.start, end, in: canvas)
        case .crop:
            pendingCrop = Self.dragRect(current.start, end, in: canvas)
        case .move:
            if begun { current.layersBefore = layers }
            moveSelectedLayer(current, to: end)
        case .eyedropper:
            break
        }
        stroke = current
    }

    /// Several pointer moves in order, as one change to the canvas: one
    /// revision whose damage covers them all, however many samples a display
    /// frame brought.
    public mutating func drags(_ moves: [(from: Mask.Point, to: Mask.Point, pressure: Double, sampling: Bool)]) {
        let start = revision
        for move in moves { drag(from: move.from, to: move.to, pressure: move.pressure, sampling: move.sampling) }
        foldRevisions(since: start)
    }

    /// Ends the drag: records its undo step, or for a click, clears what a
    /// click clears.
    public mutating func endDrag() {
        guard var done = stroke else { return }
        stroke = nil
        switch done.tool {
        case .brush, .eraser:
            paint(&done, adding: nil, pressure: 1)
            guard let id = done.layerID, !done.before.isEmpty else { return }
            record(.tiles(layer: id, done.before), named: done.tool == .brush ? "Paint" : "Erase")
        case .clone, .heal:
            guard let id = done.layerID, !done.before.isEmpty else { return }
            record(.tiles(layer: id, done.before), named: done.tool == .heal ? "Heal" : "Clone")
        case .marquee, .crop, .eyedropper:
            break
        case .move:
            if done.layersBefore != layers, !done.layersBefore.isEmpty {
                record(.layers(done.layersBefore, selected: selectedLayerID), named: "Move Layer")
            }
        }
    }

    /// The centripetal Catmull-Rom curve from `p1` to `p2`, with `p0` before
    /// and `p3` after, as points from `p1` to `p2` whose chords stay within a
    /// quarter pixel of it.
    static func curve(_ p0: Mask.Point, _ p1: Mask.Point, _ p2: Mask.Point, _ p3: Mask.Point) -> [Mask.Point] {
        // Knot spacing is the square root of each chord; tiny chords count as 1e-6.
        func knot(_ a: Mask.Point, _ b: Mask.Point) -> Double {
            max(((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot().squareRoot(), 1e-6)
        }
        let (t01, t12, t23) = (knot(p0, p1), knot(p1, p2), knot(p2, p3))
        // The tangents at p1 and p2 over this segment, as Bezier handles.
        func handle(_ a: Mask.Point, _ b: Mask.Point, _ c: Mask.Point, _ ab: Double, _ bc: Double, _ sign: Double)
            -> Mask.Point
        {
            let m = { (u: Double, v: Double, w: Double) in (v - u) / ab - (w - u) / (ab + bc) + (w - v) / bc }
            return Mask.Point(x: b.x + sign * t12 * m(a.x, b.x, c.x) / 3, y: b.y + sign * t12 * m(a.y, b.y, c.y) / 3)
        }
        let (b1, b2) = (handle(p0, p1, p2, t01, t12, 1), handle(p1, p2, p3, t12, t23, -1))
        // How far the curve bends from its chord bounds the pieces it needs.
        func bend(_ a: Mask.Point, _ b: Mask.Point, _ c: Mask.Point) -> Double {
            let (x, y) = (a.x - 2 * b.x + c.x, a.y - 2 * b.y + c.y)
            return (x * x + y * y).squareRoot()
        }
        let most = max(bend(p1, b1, b2), bend(b1, b2, p2))
        let n = most.isFinite ? min(max(Int((3 * most).squareRoot().rounded(.up)), 1), 64) : 1
        return (0...n).map { k in
            let t = Double(k) / Double(n), u = 1 - t
            let (w0, w1, w2, w3) = (u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t)
            return Mask.Point(
                x: w0 * p1.x + w1 * b1.x + w2 * b2.x + w3 * p2.x, y: w0 * p1.y + w1 * b1.y + w2 * b2.y + w3 * p2.y)
        }
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

    /// Adds a pointer sample to the stroke (nil: the stroke ends) and paints
    /// what that makes paintable: the first sample's dab, then the segment
    /// before the newest sample, or on the end the last segment.
    private mutating func paint(_ current: inout PhotoStroke, adding point: Mask.Point?, pressure: Double) {
        if let point {
            guard point.x.isFinite, point.y.isFinite, abs(point.x) < 1e7, abs(point.y) < 1e7,
                current.samples.last?.point != point
            else { return }
            let clamped = pressure.isNaN ? 1 : min(max(pressure, 0), 1)
            current.samples = current.samples.suffix(3) + [PhotoStroke.Sample(point: point, pressure: clamped)]
        }
        let s = current.samples, n = s.count
        if point != nil, n == 1 { return lay([s[0].point], from: s[0].pressure, to: s[0].pressure, &current) }
        // The segment ends at sample `last`: the one before the newest, or on the end the newest.
        let last = point == nil ? n - 1 : n - 2
        guard last >= 1 else { return }
        // Past either end the curve runs on straight: sample i's neighbor j, mirrored through it.
        func mirror(_ i: Int, _ j: Int) -> Mask.Point {
            Mask.Point(x: 2 * s[i].point.x - s[j].point.x, y: 2 * s[i].point.y - s[j].point.y)
        }
        let before = last >= 2 ? s[last - 2].point : mirror(last - 1, last)
        let after = last + 1 < n ? s[last + 1].point : mirror(last, last - 1)
        lay(Self.curve(before, s[last - 1].point, s[last].point, after), from: s[last - 1].pressure,
            to: s[last].pressure, &current)
    }

    /// Paints capsules along `points` (canvas pixels) on the stroke's layer,
    /// the pressure going from `start` to `end`; one point paints a dab.
    private mutating func lay(
        _ points: [Mask.Point], from start: Double, to end: Double, _ current: inout PhotoStroke
    ) {
        guard !points.isEmpty, let id = current.layerID, let at = index(of: id),
            var tiled = pixels.removeValue(forKey: id)
        else { return }
        let pieces = max(points.count - 1, 1)
        var touched = PixelRect(x: 0, y: 0, width: 0, height: 0)
        for k in 0..<pieces {
            let (a, b) = (Double(k) / Double(pieces), Double(k + 1) / Double(pieces))
            // Every index is inside the buffer and every value finite, so a capsule can't throw.
            let ends = (points[k], points[min(k + 1, points.count - 1)])
            if let area = try? capsule(
                ends.0, ends.1, pressures: (start + (end - start) * a, start + (end - start) * b), on: &tiled,
                layer: layers[at], stroke: &current)
            {
                touched = touched.union(area)
            }
        }
        pixels[id] = tiled
        if !touched.isEmpty { touch(.region(touched)) }
    }

    /// One capsule from `a` to `b` (canvas pixels), its radius following the
    /// pressure from one end to the other. Returns the canvas region it
    /// covers, or nil when it missed the layer.
    private func capsule(
        _ a: Mask.Point, _ b: Mask.Point, pressures: (Double, Double), on tiled: inout TiledPixels, layer: PhotoLayer,
        stroke: inout PhotoStroke
    ) throws -> PixelRect? {
        let options = stroke.tool == .eraser ? eraserOptions : brushOptions
        // Half a pixel at the least, so the soft edge below is never zero wide.
        let ra = max(options.size / 2 * pressures.0, 0.5), rb = max(options.size / 2 * pressures.1, 0.5)
        let ax = a.x - Double(layer.offsetX), ay = a.y - Double(layer.offsetY)
        let dx = b.x - a.x, dy = b.y - a.y, length2 = dx * dx + dy * dy, r = max(ra, rb)
        let box = PixelRect(
            from: Mask.Point(x: min(ax, ax + dx) - r, y: min(ay, ay + dy) - r),
            to: Mask.Point(x: max(ax, ax + dx) + r, y: max(ay, ay + dy) + r))
        guard let area = box.intersection(PixelRect(x: 0, y: 0, width: tiled.width, height: tiled.height)) else {
            return nil
        }
        let hardness = options.hardnessPercent / 100
        let opacity = Float(options.opacityPercent / 100)
        let paint = options.linearColor
        let erasing = stroke.tool == .eraser
        for i in tiled.tileIndices(in: area) where tiled.tiles.indices.contains(i) {
            let rect = tiled.tileRect(i)
            guard let part = area.intersection(rect) else { continue }
            // The tile as it was before the stroke: kept from the first paint in it on.
            let base = stroke.before[i] ?? tiled.tiles[i]
            var coverage =
                stroke.coverage.removeValue(forKey: i) ?? [Float](repeating: 0, count: rect.width * rect.height)
            var painted = false
            for y in part.y..<part.maxY {
                for x in part.x..<part.maxX {
                    // The nearest point of the piece, and the radius there.
                    let px = Double(x) + 0.5 - ax, py = Double(y) + 0.5 - ay
                    let along = length2 > 0 ? min(max((px * dx + py * dy) / length2, 0), 1) : 0
                    let ex = px - along * dx, ey = py - along * dy, radius = ra + (rb - ra) * along
                    // Coverage falls from 1 to 0 over the soft edge: the outer (1 - hardness)
                    // of the radius, and never less than a pixel, so hard edges antialias.
                    let softness = max((1 - hardness) * radius, min(1, radius))
                    let t = min(max((radius - (ex * ex + ey * ey).squareRoot()) / softness, 0), 1)
                    let cover = Float(t * t * (3 - 2 * t))
                    let (tx, ty) = (x - rect.x, y - rect.y)
                    let j = ty * rect.width + tx
                    guard cover > coverage[j] else { continue }
                    coverage[j] = cover
                    let a = cover * opacity, keep = 1 - cover * opacity
                    let p = try base.pixel(x: tx, y: ty)
                    let out = erasing
                        ? RGBA(r: p.r * keep, g: p.g * keep, b: p.b * keep, a: p.a * keep)
                        : RGBA(r: paint.r * a + p.r * keep, g: paint.g * a + p.g * keep, b: paint.b * a + p.b * keep,
                               a: a + p.a * keep)
                    try tiled.tiles[i].setPixel(x: tx, y: ty, out)
                    painted = true
                }
            }
            guard painted || stroke.before[i] != nil else { continue }
            stroke.before[i] = base
            stroke.coverage[i] = coverage
        }
        return area.offsetBy(layer.offsetX, layer.offsetY)
    }
}
