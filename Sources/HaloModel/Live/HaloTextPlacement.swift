// Live/HaloTextPlacement.swift: where a text item's raster lands (VP-5). An
// item's matrix is translate * rotate * scale (v1 has no skew), so it splits
// into a scale on each axis, a clockwise turn in degrees and the world point
// the line box's center maps to. A mirror (det <= 0) or a non-finite matrix
// gives no placement, and the renderer counts that text as skipped.
// Linux-safe.
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

struct HaloTextPlacement: Equatable {
    var scaleX: Double
    var scaleY: Double
    var degrees: Double
    /// The bounds' center in composition space.
    var center: HaloPoint

    init?(_ item: HaloDrawItem) {
        let m = item.matrix
        let det = m.determinant
        guard [m.a, m.b, m.c, m.d, m.tx, m.ty].allSatisfy(\.isFinite), det.isFinite, det > 0 else { return nil }
        let sx = (m.a * m.a + m.b * m.b).squareRoot()
        guard sx > 0 else { return nil }
        let b = item.bounds
        let center = m.apply(HaloPoint(x: b.x + b.width / 2, y: b.y + b.height / 2))
        guard center.x.isFinite, center.y.isFinite else { return nil }
        scaleX = sx
        scaleY = det / sx
        // Snapped onto a quarter turn within 1e-9, so 90 degrees takes the exact turn.
        let turn = atan2(m.b, m.a) * 180 / Double.pi
        let quarter = (turn / 90).rounded() * 90
        degrees = abs(turn - quarter) < 1e-9 ? quarter : turn
        self.center = center
    }
}
