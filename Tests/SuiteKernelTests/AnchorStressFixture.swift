// AnchorStressFixture.swift (pen-paths PN-1): 500 ten-point stars (radii 14, 6) in Flare's stress layout.
import Foundation
import SuiteKernel
enum AnchorStressFixture {
    /// `stars` closed stars of ten corner anchors, 25 across every 44 pt and down every 40 pt from (22, 22).
    static func path(stars: Int = 500) -> VectorPath {
        VectorPath(contours: (0..<stars).map { k in
            let (x, y) = (22 + Double(k % 25) * 44, 22 + Double(k / 25) * 40)
            return VectorContour(anchors: (0..<10).map { i in
                let (r, a) = (i.isMultiple(of: 2) ? 14.0 : 6.0, Double(i) * .pi / 5)
                return VectorAnchor(point: Point(x: x + r * cos(a), y: y + r * sin(a)))
            }, closed: true)
        })
    }
    static let stress = path()
}
