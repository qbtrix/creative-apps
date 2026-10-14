// PhotoRetouch.swift: the clone stamp (#422; Heal comes later). The Clone
// tool's canvas Option-click calls `setCloneSource(at:)`, its drags clone
// through `drag` (PhotoStroke), and `clone(along:size:)` is one whole stroke
// at once. `setCloneSource(at:)` samples a source
// point on the canvas. The first clone stroke after that fixes the offset from
// where it starts to the source, in whole pixels, and later strokes keep it
// until the source is sampled again. A stroke lays round dabs of the given
// size along its points, spaced a quarter of the size apart, on the selected
// layer, each pixel taking the source pixel at the offset; the brush's
// hardness gives the soft edge and its opacity how much shows, and each pixel
// keeps the most coverage the stroke gave it. Dabs read the layer as it was
// before the stroke, so a stroke never re-clones its own paint; a source
// pixel off the layer leaves the pixel alone. One stroke is one undo step
// ("Clone"), kept as the tiles it changed. Sampling a source is not a
// document edit, so it is not undoable.
//
// ponytail: the copy runs pixel by pixel here, like the brush's capsules;
// CoreRaster's clone through a mask (creative-core #232) replaces it once the
// pinned core has it. Linux-safe.
import CoreRaster

/// Where the clone stamp copies from.
public struct CloneSource: Sendable, Equatable {
    /// The sampled point, in canvas pixels.
    public let point: Mask.Point
    /// Source minus destination in whole pixels, set by the first stroke after
    /// sampling; nil until then.
    public let offset: (x: Int, y: Int)?

    public static func == (lhs: CloneSource, rhs: CloneSource) -> Bool {
        lhs.point == rhs.point && lhs.offset?.x == rhs.offset?.x && lhs.offset?.y == rhs.offset?.y
    }
}

extension PhotoWorkspace {
    /// Samples the clone source at `point` (canvas pixels) and forgets the
    /// offset, so the next stroke sets it again. Ignored with no image open or
    /// a point off the canvas.
    /// Also ignored while a clone drag is under way, so its offset holds.
    public mutating func setCloneSource(at point: Mask.Point) {
        guard stroke?.tool != .clone, let canvas, point.x.isFinite, point.y.isFinite, point.x >= 0, point.y >= 0,
            point.x < Double(canvas.width), point.y < Double(canvas.height)
        else { return }
        cloneSource = CloneSource(point: point, offset: nil)
    }

    /// Clones along `points` (canvas pixels, the first where the stroke
    /// starts) with round dabs `size` pixels across, onto the selected layer,
    /// as one undo step "Clone". Ignored with no source sampled, no points or
    /// a size that isn't finite; the size clamps to the brush's range. Records
    /// nothing when no pixel changed.
    public mutating func clone(along points: [Mask.Point], size: Double) {
        guard let first = points.first else { return }
        var current = PhotoStroke(tool: .clone, start: first, layerID: selectedLayerID)
        cloneDabs(&current, along: points, size: size)
        recordClone(current)
    }

    /// The clone tool's drag: clones from the last pointer sample to `end`
    /// with the brush's size, so the paint shows while the pointer moves;
    /// `endDrag` records the whole drag as one "Clone".
    mutating func cloneDrag(_ current: inout PhotoStroke, to end: Mask.Point) {
        let from = current.samples.last?.point ?? current.start
        current.samples = [PhotoStroke.Sample(point: end, pressure: 1)]
        cloneDabs(&current, along: [from, end], size: brushOptions.size)
    }

    /// Records a finished clone stroke as one undo step, if it changed a pixel.
    mutating func recordClone(_ done: PhotoStroke) {
        guard let id = done.layerID, !done.before.isEmpty else { return }
        record(.tiles(layer: id, done.before), named: "Clone")
    }

    /// Lays clone dabs along `points` on the stroke's layer, keeping each
    /// changed tile as it was before the stroke in `current.before`. The
    /// first dabs after sampling fix the source offset.
    private mutating func cloneDabs(_ current: inout PhotoStroke, along points: [Mask.Point], size: Double) {
        guard let source = cloneSource, let first = points.first, size.isFinite,
            points.allSatisfy({ $0.x.isFinite && $0.y.isFinite && abs($0.x) < 1e7 && abs($0.y) < 1e7 }),
            let id = current.layerID, let at = index(of: id), var tiled = pixels.removeValue(forKey: id)
        else { return }
        let offset =
            source.offset ?? (Int((source.point.x - first.x).rounded()), Int((source.point.y - first.y).rounded()))
        cloneSource = CloneSource(point: source.point, offset: offset)
        let diameter = min(max(size, ToolOptions.sizeRange.lowerBound), ToolOptions.sizeRange.upperBound)
        let layer = layers[at]
        var touched = PixelRect(x: 0, y: 0, width: 0, height: 0)
        for center in Self.dabCenters(points, spacing: max(diameter / 4, 1)) {
            let dab = Mask.Point(x: center.x - Double(layer.offsetX), y: center.y - Double(layer.offsetY))
            // Every index is inside the layer and every value finite, so a dab can't throw.
            if let area = try? cloneDab(
                at: dab, radius: diameter / 2, offset: offset, on: &tiled, before: &current.before,
                coverage: &current.coverage)
            {
                touched = touched.union(area.offsetBy(layer.offsetX, layer.offsetY))
            }
        }
        pixels[id] = tiled
        if !touched.isEmpty { touch(.region(touched)) }
    }

    /// `points` with dabs filled in so no two in a row are more than
    /// `spacing` apart; at most 10,000 between any two.
    static func dabCenters(_ points: [Mask.Point], spacing: Double) -> [Mask.Point] {
        guard let first = points.first else { return [] }
        var centers = [first]
        for (a, b) in zip(points, points.dropFirst()) {
            let dx = b.x - a.x, dy = b.y - a.y
            let n = min(max(Int(((dx * dx + dy * dy).squareRoot() / spacing).rounded(.up)), 1), 10_000)
            for k in 1...n {
                let t = Double(k) / Double(n)
                centers.append(Mask.Point(x: a.x + dx * t, y: a.y + dy * t))
            }
        }
        return centers
    }

    /// One round dab at `center` (layer pixels) copying from `offset` away.
    /// Returns the layer region it changed, or nil when it changed nothing.
    private func cloneDab(
        at center: Mask.Point, radius: Double, offset: (x: Int, y: Int), on tiled: inout TiledPixels,
        before: inout [Int: PixelBuffer], coverage: inout [Int: [Float]]
    ) throws -> PixelRect? {
        let box = PixelRect(
            from: Mask.Point(x: center.x - radius, y: center.y - radius),
            to: Mask.Point(x: center.x + radius, y: center.y + radius))
        guard let area = box.intersection(PixelRect(x: 0, y: 0, width: tiled.width, height: tiled.height)) else {
            return nil
        }
        let hardness = brushOptions.hardnessPercent / 100
        let opacity = Float(brushOptions.opacityPercent / 100)
        // Coverage falls from 1 to 0 over the outer (1 - hardness) of the radius, never under a pixel.
        let softness = max((1 - hardness) * radius, min(1, radius))
        var changed = PixelRect(x: 0, y: 0, width: 0, height: 0)
        for i in tiled.tileIndices(in: area) where tiled.tiles.indices.contains(i) {
            let rect = tiled.tileRect(i)
            guard let part = area.intersection(rect) else { continue }
            // Saved up front so this tile's own source pixels read as they were.
            let saved = before[i] != nil, base = before[i] ?? tiled.tiles[i]
            before[i] = base
            var cover = coverage.removeValue(forKey: i) ?? [Float](repeating: 0, count: rect.width * rect.height)
            var painted = false
            for y in part.y..<part.maxY {
                for x in part.x..<part.maxX {
                    let px = Double(x) + 0.5 - center.x, py = Double(y) + 0.5 - center.y
                    let t = min(max((radius - (px * px + py * py).squareRoot()) / softness, 0), 1)
                    let c = Float(t * t * (3 - 2 * t))
                    let j = (y - rect.y) * rect.width + (x - rect.x)
                    guard c > cover[j],
                        let s = try sourcePixel(x: x + offset.x, y: y + offset.y, in: tiled, before: before)
                    else { continue }
                    cover[j] = c
                    let a = c * opacity, keep = 1 - a
                    let p = try base.pixel(x: x - rect.x, y: y - rect.y)
                    let out = RGBA(
                        r: s.r * a + p.r * keep, g: s.g * a + p.g * keep, b: s.b * a + p.b * keep, a: s.a * a + p.a * keep)
                    guard out != (try tiled.tiles[i].pixel(x: x - rect.x, y: y - rect.y)) else { continue }
                    try tiled.tiles[i].setPixel(x: x - rect.x, y: y - rect.y, out)
                    painted = true
                    changed = changed.union(PixelRect(x: x, y: y, width: 1, height: 1))
                }
            }
            coverage[i] = cover
            if !painted, !saved { before[i] = nil }
        }
        return changed.isEmpty ? nil : changed
    }

    /// The layer pixel at (`x`, `y`) as it was before the stroke; nil off the layer.
    private func sourcePixel(x: Int, y: Int, in tiled: TiledPixels, before: [Int: PixelBuffer]) throws -> RGBA? {
        guard (0..<tiled.width).contains(x), (0..<tiled.height).contains(y) else { return nil }
        let size = PixelBuffer.tileSize, i = (y / size) * tiled.columns + x / size
        guard tiled.tiles.indices.contains(i) else { return nil }
        return try (before[i] ?? tiled.tiles[i]).pixel(x: x % size, y: y % size)
    }
}
