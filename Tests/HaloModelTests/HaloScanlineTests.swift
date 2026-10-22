// HaloScanlineTests.swift (stroke-style HK-5): HaloScanline's row-at-a-time
// coverage matches CoreRaster's Mask.polygon sample for sample.
import CoreRaster
@testable import HaloModel
import Testing

@Suite struct HaloScanlineTests {
    /// Mask.polygon's coverage of `points` on a `w` × `h` frame, row-major.
    static func reference(_ points: [HaloPoint], w: Int, h: Int) throws -> [Float] {
        let mask = try Mask.polygon(width: w, height: h, points: points.map { Mask.Point(x: $0.x, y: $0.y) })
        var out: [Float] = []
        for y in 0..<h { for x in 0..<w { out.append(try mask.coverage(x: x, y: y)) } }
        return out
    }

    static let shapes: [[HaloPoint]] = [
        // A star crossing the frame's left and top edges.
        [(-3.0, 4.0), (9.3, 6.1), (14.0, -2.5), (17.2, 8.8), (29.9, 11.0), (19.4, 17.6), (21.0, 30.2), (12.2, 21.3), (2.6, 27.0), (6.7, 16.4)]
            .map { HaloPoint(x: $0.0, y: $0.1) },
        // A ring bridged to its hole the way HaloOutlines joins a stroke's rings.
        [(2.0, 2.0), (22.0, 2.0), (22.0, 22.0), (2.0, 22.0), (2.0, 2.0), (8.25, 8.5), (8.25, 15.75), (15.5, 15.75), (15.5, 8.5), (8.25, 8.5), (2.0, 2.0)]
            .map { HaloPoint(x: $0.0, y: $0.1) },
    ]

    @Test(arguments: shapes)
    func matchesMaskPolygon(_ points: [HaloPoint]) throws {
        let got = HaloScanline.coverage(points, width: 24, height: 24)
        let want = try Self.reference(points, w: 24, h: 24)
        #expect(got == want)
        #expect(got.contains { $0 > 0 && $0 < 1 })
    }

    @Test func fewerThanThreePointsCoverNothing() {
        let got = HaloScanline.coverage([HaloPoint(x: 0, y: 0), HaloPoint(x: 9, y: 9)], width: 4, height: 4)
        #expect(got == [Float](repeating: 0, count: 16))
    }
}
