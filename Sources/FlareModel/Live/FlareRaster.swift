// FlareRaster.swift: FrameRasterizing in plain Swift, so PNG frames draw on Linux and in the CLI as well as in the
// window, masks and mattes included (flare-export QB gate #6200). One StageDrawList becomes straight-alpha RGBA8
// pixels on a premultiplied Float canvas: the background unless transparent, then every non-text item in paint
// order, its fill (solid, linear or radial, padded past the ends, stops mixed in straight sRGB as CoreGraphics
// mixes them) and its stroke (the trimmed, dashed `strokePath` outlined by FlareCore at the stroke's width, join and
// cap, miter limit 10 as CoreGraphics' default), each at the item's opacity. Coverage is nonzero winding sampled on
// 4 sub-rows per pixel with exact horizontal span overlap, inside the shape's pixel box only.
// An item's `clips` (its layer's and host layers' masks) gate it as the SVG export's CSS masks do: masks of one depth
// combine by mode from black when the first adds, else white (add, subtract, intersect, difference; inverted swaps
// inside and outside; feather blurs with sigma feather / 3; opacity scales the paint), and depths multiply. A `matte`
// gates it by its source items drawn on their own: alpha, or luminance of the premultiplied colour, the inverted
// kinds one minus that. Masks and mattes are built once per distinct value per frame. `encode` turns the frame
// into PNG bytes; the window passes ImageIO, the CLI CoreRaster. Sizes are checked before anything is allocated;
// nothing here can trap.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
import SuiteModel

public struct FlareRaster: FrameRasterizing {
    /// The longest side in pixels this draws, as StageRasterizer's.
    public static let maxSide = 16_384
    /// The frame as PNG bytes.
    public var encode: @Sendable (MediaFrame) throws -> Data

    public init(encode: @escaping @Sendable (MediaFrame) throws -> Data) { self.encode = encode }

    public func png(_ list: StageDrawList, scale: Double, transparent: Bool) throws -> Data {
        let w = list.width * scale, h = list.height * scale
        guard w.isFinite, h.isFinite, w >= 0.5, h >= 0.5, w <= Double(Self.maxSide), h <= Double(Self.maxSide) else {
            throw FlareRasterError.invalidSize
        }
        return try encode(Self.render(list, width: Int(w.rounded()), height: Int(h.rounded()), transparent: transparent))
    }

    public func frame(_ list: StageDrawList, width: Int, height: Int, transparent: Bool) throws -> MediaFrame {
        try Self.render(list, width: width, height: height, transparent: transparent)
    }

    /// `list` drawn to fill exactly `width` × `height` pixels, each axis scaled on its own.
    public static func render(_ list: StageDrawList, width: Int, height: Int, transparent: Bool) throws -> MediaFrame {
        guard width >= 1, height >= 1, width <= maxSide, height <= maxSide,
              list.width.isFinite, list.height.isFinite, list.width > 0, list.height > 0
        else { throw FlareRasterError.invalidSize }
        var canvas = Canvas(width: width, height: height, sx: Double(width) / list.width, sy: Double(height) / list.height)
        if !transparent { canvas.fill(list.background) }
        var masks: [[ClipMask]: [Float]] = [:], mattes: [MatteLink: [Float]] = [:]
        for item in list.items where !item.isText {
            var gate: [Float]?
            if !item.clips.isEmpty {
                let mask = masks[item.clips] ?? canvas.mask(item.clips)
                masks[item.clips] = mask
                gate = mask
            }
            if let link = item.matte {
                let matte = mattes[link] ?? canvas.matte(link, list)
                mattes[link] = matte
                gate = gate.map { zip($0, matte).map { $0 * $1 } } ?? matte
            }
            canvas.draw(item, gate: gate)
        }
        return try MediaFrame(width: width, height: height, rgba: canvas.straightBytes())
    }
}

public enum FlareRasterError: Error, Equatable {
    /// The list's size times the scale is zero, negative, not finite or past `FlareRaster.maxSide`.
    case invalidSize
}

/// A premultiplied RGBA canvas, `sx` and `sy` pixels per scene point.
struct Canvas {
    let width: Int, height: Int, sx: Double, sy: Double
    var pixels: [Float]

    init(width: Int, height: Int, sx: Double, sy: Double) {
        (self.width, self.height, self.sx, self.sy) = (width, height, sx, sy)
        pixels = [Float](repeating: 0, count: width * height * 4)
    }

    mutating func fill(_ color: FlareColor) {
        let a = Float(clamp(color.a))
        let px = [Float(clamp(color.r)) * a, Float(clamp(color.g)) * a, Float(clamp(color.b)) * a, a]
        for i in stride(from: 0, to: pixels.count, by: 4) { for k in 0..<4 { pixels[i + k] = px[k] } }
    }

    /// One item: fill, then stroke, each at its opacity and `gate` (a full-canvas multiplier), source over.
    mutating func draw(_ item: StageItem, gate: [Float]?) {
        let stretch = abs(item.transform.determinant).squareRoot()
        let tolerance = localTolerance(stretch)
        if let fill = item.fill, let cover = coverage(item.path, item.transform, tolerance) {
            paint(cover, fill, item.transform, stretch, item.opacity, gate)
        }
        if let stroke = item.stroke, stroke.width > 0, stroke.width.isFinite,
           let outline = try? (item.strokePath ?? item.path).outlined(
               width: stroke.width, join: stroke.join, cap: stroke.cap, miterLimit: 10, tolerance: tolerance),
           let cover = coverage(outline, item.transform, tolerance) {
            paint(cover, .solid(stroke.color), item.transform, stretch, item.opacity, gate)
        }
    }

    /// The full-canvas value of `clips`: each depth's masks combined by mode, depths multiplied.
    func mask(_ clips: [ClipMask]) -> [Float] {
        var total = [Float](repeating: 1, count: width * height)
        var start = 0
        while start < clips.count {
            let depth = clips[start].depth
            var end = start
            while end < clips.count, clips[end].depth == depth { end += 1 }
            var v = [Float](repeating: clips[start].mode == .add ? 0 : 1, count: width * height)
            for clip in clips[start..<end] {
                var c = full(coverage(clip.path, Matrix(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0), localTolerance(1)))
                if clip.feather > 0, clip.feather.isFinite { blur(&c, sigma: clip.feather / 3 * (sx + sy) / 2) }
                let o = Float(clamp(clip.opacity))
                for i in v.indices {
                    let inside = clip.inverted ? 1 - c[i] : c[i]
                    switch clip.mode {
                    case .add: v[i] += o * inside * (1 - v[i])
                    case .subtract: v[i] *= 1 - o * inside
                    case .intersect: v[i] *= 1 - o * (1 - inside)
                    case .difference: v[i] += o * inside * (1 - 2 * v[i])
                    }
                }
            }
            for i in total.indices { total[i] *= v[i] }
            start = end
        }
        return total
    }

    /// The full-canvas value of a track matte: its source items drawn alone, read as alpha or luminance.
    func matte(_ link: MatteLink, _ list: StageDrawList) -> [Float] {
        let pool = link.inMatteItems ? list.matteItems : list.items
        var source = Canvas(width: width, height: height, sx: sx, sy: sy)
        for i in link.sourceItems.clamped(to: pool.indices) where !pool[i].isText {
            var item = pool[i]
            item.matte = nil
            source.draw(item, gate: item.clips.isEmpty ? nil : source.mask(item.clips))
        }
        let p = source.pixels
        return (0..<(width * height)).map { i in
            let value: Float = switch link.kind {
            case .alpha, .alphaInverted: p[i * 4 + 3]
            case .luma, .lumaInverted: 0.2126 * p[i * 4] + 0.7152 * p[i * 4 + 1] + 0.0722 * p[i * 4 + 2]
            }
            return link.kind == .alpha || link.kind == .luma ? value : 1 - value
        }
    }

    /// Straight-alpha RGBA8, rounded to nearest.
    func straightBytes() -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: pixels.count)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = min(max(pixels[i + 3], 0), 1)
            guard a > 0 else { continue }
            for k in 0..<3 { bytes[i + k] = byte(pixels[i + k] / a) }
            bytes[i + 3] = byte(a)
        }
        return bytes
    }

    // MARK: - Coverage

    /// A coverage box: its pixel origin and size, values 0...1 row by row.
    struct Cover { var x0: Int, y0: Int, w: Int, h: Int, values: [Float] }

    /// Flattening tolerance in local units for about a fifth of a pixel through a matrix that stretches by `stretch`.
    func localTolerance(_ stretch: Double) -> Double {
        let pixels = stretch * max(sx, sy)
        return pixels.isFinite && pixels > 1e-9 ? min(max(0.2 / pixels, 1e-4), 10) : 1
    }

    /// Nonzero coverage of `path` through `matrix`, inside its pixel box; nil when it covers no pixel.
    func coverage(_ path: FlarePath, _ matrix: Matrix, _ tolerance: Double) -> Cover? {
        guard let polylines = try? path.flattened(tolerance: tolerance) else { return nil }
        struct Edge { var top: Double, bottom: Double, x: Double, slope: Double, dir: Int }
        var edges: [Edge] = []
        var minX = Double.infinity, minY = Double.infinity, maxX = -Double.infinity, maxY = -Double.infinity
        for line in polylines where line.count > 1 {
            let pts = line.map { p -> (Double, Double) in let q = matrix.apply(p); return (q.x * sx, q.y * sy) }
            for i in pts.indices {
                let p = pts[i], q = pts[(i + 1) % pts.count]
                guard p.0.isFinite, p.1.isFinite, q.0.isFinite, q.1.isFinite else { return nil }
                minX = min(minX, p.0); maxX = max(maxX, p.0); minY = min(minY, p.1); maxY = max(maxY, p.1)
                guard p.1 != q.1 else { continue }
                let (a, b, dir) = p.1 < q.1 ? (p, q, 1) : (q, p, -1)
                edges.append(Edge(top: a.1, bottom: b.1, x: a.0, slope: (b.0 - a.0) / (b.1 - a.1), dir: dir))
            }
        }
        guard !edges.isEmpty, minX < Double(width), minY < Double(height), maxX > 0, maxY > 0 else { return nil }
        let x0 = max(0, Int(minX.rounded(.down))), x1 = min(width, Int(maxX.rounded(.up)))
        let y0 = max(0, Int(minY.rounded(.down))), y1 = min(height, Int(maxY.rounded(.up)))
        guard x1 > x0, y1 > y0 else { return nil }
        let w = x1 - x0
        var values = [Float](repeating: 0, count: w * (y1 - y0))
        edges.sort { $0.top < $1.top }
        var next = 0, active: [Edge] = [], hits: [(x: Double, dir: Int)] = []
        for row in y0..<y1 {
            let base = (row - y0) * w
            for sub in 0..<4 {
                let y = Double(row) + (Double(sub) + 0.5) / 4
                while next < edges.count, edges[next].top <= y { active.append(edges[next]); next += 1 }
                active.removeAll { $0.bottom <= y }
                hits.removeAll(keepingCapacity: true)
                for e in active where e.top <= y { hits.append((e.x + (y - e.top) * e.slope, e.dir)) }
                hits.sort { $0.x < $1.x }
                var wind = 0, start = 0.0
                for hit in hits {
                    let before = wind
                    wind += hit.dir
                    if before == 0, wind != 0 { start = hit.x }
                    if before != 0, wind == 0 { span(&values, base, x0, x1, start, hit.x) }
                }
            }
        }
        return Cover(x0: x0, y0: y0, w: w, h: y1 - y0, values: values)
    }

    /// Adds a quarter of `from..<to`'s overlap with each pixel of one row.
    private func span(_ values: inout [Float], _ base: Int, _ x0: Int, _ x1: Int, _ from: Double, _ to: Double) {
        let a = max(from, Double(x0)), b = min(to, Double(x1))
        guard b > a else { return }
        let ia = Int(a.rounded(.down)), ib = Int(b.rounded(.down))
        if ia == ib { values[base + ia - x0] += Float(0.25 * (b - a)); return }
        values[base + ia - x0] += Float(0.25 * (Double(ia + 1) - a))
        for x in (ia + 1)..<ib { values[base + x - x0] += 0.25 }
        if ib < x1 { values[base + ib - x0] += Float(0.25 * (b - Double(ib))) }
    }

    /// A coverage box spread over the whole canvas.
    private func full(_ cover: Cover?) -> [Float] {
        var out = [Float](repeating: 0, count: width * height)
        guard let cover else { return out }
        for row in 0..<cover.h {
            for x in 0..<cover.w { out[(cover.y0 + row) * width + cover.x0 + x] = min(cover.values[row * cover.w + x], 1) }
        }
        return out
    }

    /// Three box blurs each way, about a Gaussian of `sigma` pixels.
    private func blur(_ v: inout [Float], sigma: Double) {
        guard sigma.isFinite, sigma >= 0.5 else { return }
        let r = Int(min(sigma, Double(max(width, height))).rounded())
        for _ in 0..<3 {
            boxPass(&v, count: height, length: width, stride: 1, step: width, r: r)
            boxPass(&v, count: width, length: height, stride: width, step: 1, r: r)
        }
    }

    /// One running-sum box blur of radius `r` along `count` lines of `length` samples, edges held.
    private func boxPass(_ v: inout [Float], count: Int, length: Int, stride: Int, step: Int, r: Int) {
        var line = [Float](repeating: 0, count: length)
        let scale = 1 / Float(2 * r + 1)
        for n in 0..<count {
            let origin = n * step
            for i in 0..<length { line[i] = v[origin + i * stride] }
            var sum: Float = 0
            for i in -r...r { sum += line[min(max(i, 0), length - 1)] }
            for i in 0..<length {
                v[origin + i * stride] = sum * scale
                sum += line[min(i + r + 1, length - 1)] - line[max(i - r, 0)]
            }
        }
    }

    // MARK: - Paint

    /// `fill` over `cover`'s pixels at `opacity`, gated, source over.
    private mutating func paint(_ cover: Cover, _ fill: Fill, _ matrix: Matrix, _ stretch: Double,
                                _ opacity: Double, _ gate: [Float]?) {
        let shade = Shade(fill, matrix, stretch)
        let o = Float(clamp(opacity))
        for row in 0..<cover.h {
            let y = cover.y0 + row
            for x in cover.x0..<(cover.x0 + cover.w) {
                var c = min(cover.values[row * cover.w + x - cover.x0], 1) * o
                guard c > 0 else { continue }
                if let gate { c *= gate[y * width + x] }
                guard c > 0 else { continue }
                let color = shade.color(at: Point(x: (Double(x) + 0.5) / sx, y: (Double(y) + 0.5) / sy))
                let a = Float(color.a) * c
                let i = (y * width + x) * 4
                pixels[i] = Float(color.r) * a + pixels[i] * (1 - a)
                pixels[i + 1] = Float(color.g) * a + pixels[i + 1] * (1 - a)
                pixels[i + 2] = Float(color.b) * a + pixels[i + 2] * (1 - a)
                pixels[i + 3] = a + pixels[i + 3] * (1 - a)
            }
        }
    }

    /// A fill's straight colour at a scene point; gradient ends are carried into scene space.
    struct Shade {
        var solid: FlareColor?, stops: [GradientStop] = []
        var start = Point(x: 0, y: 0), axis = Point(x: 0, y: 0), lengthSquared = 0.0, radius = 0.0, radial = false

        init(_ fill: Fill, _ matrix: Matrix, _ stretch: Double) {
            switch fill {
            case .solid(let color): solid = color
            case .linear(let stops, let a, let b):
                self.stops = stops.sorted { $0.offset < $1.offset }
                start = matrix.apply(a)
                let end = matrix.apply(b)
                axis = Point(x: end.x - start.x, y: end.y - start.y)
                lengthSquared = axis.x * axis.x + axis.y * axis.y
            case .radial(let stops, let center, let r):
                self.stops = stops.sorted { $0.offset < $1.offset }
                start = matrix.apply(center); radius = r * stretch; radial = true
            }
        }

        func color(at p: Point) -> FlareColor {
            if let solid { return clamped(solid) }
            guard let first = stops.first, let last = stops.last else { return FlareColor(r: 0, g: 0, b: 0, a: 0) }
            let dx = p.x - start.x, dy = p.y - start.y
            var t: Double
            if radial { t = radius > 0 ? (dx * dx + dy * dy).squareRoot() / radius : 1 }
            else { t = lengthSquared > 0 ? (dx * axis.x + dy * axis.y) / lengthSquared : 0 }
            if !t.isFinite { t = 0 }
            if t <= first.offset { return clamped(first.color) }
            if t >= last.offset { return clamped(last.color) }
            for (a, b) in zip(stops, stops.dropFirst()) where t <= b.offset {
                let span = b.offset - a.offset
                let f = span > 0 ? (t - a.offset) / span : 1
                return clamped(FlareColor(r: a.color.r + (b.color.r - a.color.r) * f, g: a.color.g + (b.color.g - a.color.g) * f,
                                          b: a.color.b + (b.color.b - a.color.b) * f, a: a.color.a + (b.color.a - a.color.a) * f))
            }
            return clamped(last.color)
        }

        private func clamped(_ c: FlareColor) -> FlareColor {
            FlareColor(r: clamp(c.r), g: clamp(c.g), b: clamp(c.b), a: clamp(c.a))
        }
    }
}

private func clamp(_ v: Double) -> Double { v.isFinite ? min(max(v, 0), 1) : 0 }
private func byte(_ v: Float) -> UInt8 { v.isNaN ? 0 : UInt8(min(max(v, 0), 1) * 255 + 0.5) }
