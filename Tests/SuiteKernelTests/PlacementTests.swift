// PlacementTests.swift (anchor-parenting AN-2, on since AN-3): a layer's
// Placement turns and scales about its anchor, moving the anchor keeps the
// layer where it is on screen, and the matrix is Halo's local matrix
// T(x, y) · R · S · T(−anchor) (HaloKeyRules.localMatrix).
import Foundation
import Testing
import SuiteKernel

@Suite struct PlacementTests {
    static let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    static func corners(_ r: Rect) -> [Point] {
        [Point(x: r.minX, y: r.minY), Point(x: r.maxX, y: r.minY), Point(x: r.maxX, y: r.maxY), Point(x: r.minX, y: r.maxY)]
    }
    static func near(_ a: Point, _ b: Point, _ tolerance: Double = 1e-9) -> Bool {
        abs(a.x - b.x) <= tolerance && abs(a.y - b.y) <= tolerance
    }

    /// A 100×100 box anchored at its centre and turned 90° keeps its centre, and the anchor lands on (x, y).
    @Test func turnsAboutTheAnchor() {
        let p = Placement(x: 50, y: 50, rotation: 90, anchorX: 50, anchorY: 50)
        #expect(Self.near(p.matrix.apply(Point(x: 50, y: 50)), Point(x: 50, y: 50)))
        #expect(Self.near(p.matrix.apply(Point(x: 0, y: 0)), Point(x: 100, y: 0)), "clockwise on a y-down page")
        let moved = Placement(x: 300, y: 200, scaleX: 2, scaleY: 3, rotation: 37, anchorX: 50, anchorY: 50)
        #expect(Self.near(moved.matrix.apply(Point(x: 50, y: 50)), Point(x: 300, y: 200)))
        #expect(Placement.identity.matrix == .identity)
    }

    /// Moving the anchor to a corner leaves every corner where it was on screen, plain and scaled 2x turned 30°.
    @Test func movingAnchorKeepsPlace() {
        let placements = [Placement(x: 50, y: 50, anchorX: 50, anchorY: 50),
                          Placement(x: 120, y: -40, scaleX: 2, scaleY: 2, rotation: 30, anchorX: 50, anchorY: 50),
                          Placement(x: 7, y: 9, scaleX: 0.5, scaleY: 1.5, rotation: -110, anchorX: 10, anchorY: 80)]
        for p in placements {
            for corner in Self.corners(Self.box) {
                let moved = p.movingAnchor(to: corner)
                #expect(moved.anchorX == corner.x && moved.anchorY == corner.y)
                #expect(moved.scaleX == p.scaleX && moved.scaleY == p.scaleY && moved.rotation == p.rotation)
                for q in Self.corners(Self.box) + [Point(x: 33, y: 71)] {
                    #expect(Self.near(moved.matrix.apply(q), p.matrix.apply(q), 1e-6), "\(p) moved to \(corner) shifts \(q)")
                }
            }
        }
    }

    /// `matrix` equals Halo's localMatrix formula for 200 seeded random placements.
    @Test func matrixMatchesHalo() {
        var seed: UInt64 = 0x5EED_A9C4
        func next(_ range: ClosedRange<Double>) -> Double {
            seed &+= 0x9E37_79B9_7F4A_7C15
            var z = seed
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            let unit = Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
            return range.lowerBound + unit * (range.upperBound - range.lowerBound)
        }
        for _ in 0..<200 {
            let p = Placement(x: next(-500...500), y: next(-500...500), scaleX: next(-3...3), scaleY: next(-3...3),
                              rotation: next(-720...720), anchorX: next(-200...200), anchorY: next(-200...200))
            // HaloKeyRules.localMatrix: translation(x, y) * rotation(degrees) * scale(sx, sy) * translation(-ax, -ay).
            // Applied right to left: the anchor to the origin, scale, turn, then move.
            let steps = [Matrix.translation(x: -p.anchorX, y: -p.anchorY), Matrix.scale(x: p.scaleX, y: p.scaleY),
                         Matrix.rotation(degrees: p.rotation), Matrix.translation(x: p.x, y: p.y)]
            for q in [Point(x: 0, y: 0), Point(x: 1, y: 0), Point(x: 0, y: 1), Point(x: next(-100...100), y: next(-100...100))] {
                let halo = steps.reduce(q) { $1.apply($0) }
                #expect(Self.near(p.matrix.apply(q), halo, 1e-6))
            }
        }
    }

    /// An anchor that isn't a finite point leaves the placement as it is.
    @Test func nonFiniteAnchorIsNoChange() {
        let p = Placement(x: 12, y: 34, scaleX: 2, scaleY: 2, rotation: 30, anchorX: 5, anchorY: 6)
        #expect(p.movingAnchor(to: Point(x: .nan, y: 0)) == p)
        #expect(p.movingAnchor(to: Point(x: 0, y: .infinity)) == p)
        #expect(p.movingAnchor(to: Point(x: p.anchorX, y: p.anchorY)) == p)
    }

    /// The nine points of a box, for the picker and `{at:}`.
    @Test func anchorPointsOfABox() {
        let r = Rect(minX: 10, minY: 20, maxX: 110, maxY: 220)
        let expected: [BoxAnchor: Point] = [
            .topLeft: Point(x: 10, y: 20), .top: Point(x: 60, y: 20), .topRight: Point(x: 110, y: 20),
            .left: Point(x: 10, y: 120), .center: Point(x: 60, y: 120), .right: Point(x: 110, y: 120),
            .bottomLeft: Point(x: 10, y: 220), .bottom: Point(x: 60, y: 220), .bottomRight: Point(x: 110, y: 220),
        ]
        for anchor in BoxAnchor.allCases {
            #expect(Placement.anchorPoint(at: anchor, in: r) == expected[anchor], "\(anchor)")
        }
    }
}
