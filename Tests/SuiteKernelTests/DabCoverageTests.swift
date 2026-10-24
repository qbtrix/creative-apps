// DabCoverageTests.swift (fill-heal FH-1 written, FH-5k on): a stroke's dab
// coverage. One hard dab covers its disc exactly, two overlapping dabs keep
// the larger coverage rather than the sum, and the grid's bounds hold every
// dab whole. Mutations (FH-5k): SuiteKernel.DabCoverage (`.overlapKeepsMax`,
// `.boundsHoldDabs`).
import Foundation
import Testing
import SuiteKernel

@Suite struct DabCoverageTests {
    /// The grid's coverage at document pixel (x, y); 0 outside it.
    static func at(_ g: CoverageGrid, _ x: Int, _ y: Int) -> Float {
        let (cx, cy) = (x - g.originX, y - g.originY)
        guard (0..<g.width).contains(cx), (0..<g.height).contains(cy), cy * g.width + cx < g.values.count else { return 0 }
        return g.values[cy * g.width + cx]
    }

    @Test func hardDabCoversItsDiscExactly() {
        let g = DabCoverage.disc(at: Point(x: 20, y: 20), size: 10, hardness: 1)
        #expect(g.originX == 15 && g.originY == 15 && g.width == 10 && g.height == 10 && g.values.count == 100)
        for y in 10..<30 {
            for x in 10..<30 {
                let d = hypot(Double(x) + 0.5 - 20, Double(y) + 0.5 - 20)
                #expect(Self.at(g, x, y) == (d <= 5 ? 1 : 0), "(\(x), \(y))")
            }
        }
    }

    @Test func overlappingDabsKeepTheMax() {
        // Spacing 100% of 10 px is wider than the 4 px between the points: two dabs, one at each end.
        let brush = BrushSettings(size: 10, hardness: 0, spacing: 100)
        let g = DabCoverage.stroke([Point(x: 20, y: 20), Point(x: 24, y: 20)], brush: brush)
        let a = DabCoverage.disc(at: Point(x: 20, y: 20), size: 10, hardness: 0)
        let b = DabCoverage.disc(at: Point(x: 24, y: 20), size: 10, hardness: 0)
        #expect(!g.values.isEmpty && g.values.allSatisfy { (0...1).contains($0) })
        for y in 14..<27 {
            for x in 14..<31 {
                #expect(Self.at(g, x, y) == max(Self.at(a, x, y), Self.at(b, x, y)), "(\(x), \(y))")
            }
        }
        #expect(Self.at(g, 22, 20) > 0.5 && Self.at(g, 22, 20) < 1)
    }

    @Test func boundsHoldEveryDab() {
        let points = [Point(x: 5, y: 5), Point(x: 60, y: 30), Point(x: 40, y: 52)]
        let g = DabCoverage.stroke(points, brush: BrushSettings(size: 12, hardness: 50, spacing: 25))
        #expect(g.originX <= -1 && g.originY <= -1 && g.originX + g.width >= 66 && g.originY + g.height >= 58)
        #expect(g.values.count == g.width * g.height)
        for p in points {
            let dab = DabCoverage.disc(at: p, size: 12, hardness: 0.5)
            for y in dab.originY..<(dab.originY + dab.height) {
                for x in dab.originX..<(dab.originX + dab.width) {
                    #expect(Self.at(g, x, y) >= Self.at(dab, x, y), "(\(x), \(y))")
                }
            }
        }
    }

    @Test func nothingToStrokeIsAnEmptyGrid() {
        #expect(DabCoverage.stroke([], brush: BrushSettings()).values.isEmpty)
        #expect(DabCoverage.disc(at: Point(x: .nan, y: 0), size: 10, hardness: 1).values.isEmpty)
        let one = DabCoverage.stroke([Point(x: 3, y: 3)], brush: BrushSettings(size: .nan))
        #expect(one.values.count == one.width * one.height)
    }
}
