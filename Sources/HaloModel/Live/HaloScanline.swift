// HaloScanline.swift (stroke-style HK-5): a polygon's even-odd coverage on
// a frame, at the same 4 × 4 sample points per pixel as CoreRaster's
// `Mask.polygon` and by the same crossing rule, found a sample row at a time:
// the row's edge crossings, sorted, cover the samples between each pair. That
// costs one pass over the edges per sample row, not per sample, which a
// stroke's outline (hundreds of points around both sides of the band) needs
// to render in time. It moves to creative-core once Mask.polygon scans rows.
// Linux-safe.
enum HaloScanline {
    /// Samples per pixel along each axis, as in CoreRaster's Mask.
    static let samples = 4

    /// The coverage (0...1) of `points` (closed implicitly) on a `width` ×
    /// `height` frame, row-major; all 0 for fewer than 3 points. The caller
    /// checks the points are finite and the size is one a buffer accepts.
    static func coverage(_ points: [HaloPoint], width: Int, height: Int) -> [Float] {
        let n = samples, step = 1 / Double(n)
        var hits = [Int](repeating: 0, count: max(width, 0) * max(height, 0))
        let ys = points.map(\.y)
        guard points.count >= 3, width > 0, height > 0, let minY = ys.min(), let maxY = ys.max() else {
            return hits.map { Float($0) }
        }
        let edges = Array(zip(points, points.dropFirst() + points.prefix(1)))
        let limit = width * n
        /// The sample column `s`'s x, the way Mask computes it.
        func sx(_ s: Int) -> Double { Double(s / n) + (Double(s % n) + 0.5) * step }
        /// The first sample column at or past `x`.
        func first(atOrPast x: Double) -> Int {
            let clamped = min(max(x, -1), Double(width) + 1)
            var s = min(max(Int((clamped * Double(n) - 0.5).rounded(.up)), 0), limit)
            while s > 0, sx(s - 1) >= clamped { s -= 1 }
            while s < limit, sx(s) < clamped { s += 1 }
            return s
        }
        let rows = Int(min(max(minY.rounded(.down), 0), Double(height)))..<Int(min(max(maxY.rounded(.up), 0), Double(height)))
        for py in rows {
            for j in 0..<n {
                let sy = Double(py) + (Double(j) + 0.5) * step
                let crossings = edges.filter { ($0.0.y > sy) != ($0.1.y > sy) }
                    .map { a, b in a.x + (sy - a.y) / (b.y - a.y) * (b.x - a.x) }.sorted()
                for k in stride(from: 0, to: crossings.count - 1, by: 2) {
                    let lo = first(atOrPast: crossings[k]), hi = first(atOrPast: crossings[k + 1])
                    for s in lo..<max(lo, hi) {
                        let i = py * width + s / n
                        if hits.indices.contains(i) { hits[i] += 1 }
                    }
                }
            }
        }
        return hits.map { Float($0) / Float(n * n) }
    }
}
