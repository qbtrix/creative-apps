// OrientationTests.swift (orientation-crop OC-2, turned on by OC-m): the eight EXIF orientations
// as a group: compose, rotate, flip, the turned size, the unit-square matrix and EXIF's numbers.
import Testing
import SuiteKernel

@Suite struct OrientationTests {
    /// Where each orientation sends a unit square's top-left corner, as EXIF 1 to 8 describe it.
    static let topLeftGoesTo: [Orientation: Point] = [
        .up: Point(x: 0, y: 0), .upMirrored: Point(x: 1, y: 0), .down: Point(x: 1, y: 1), .downMirrored: Point(x: 0, y: 1),
        .leftMirrored: Point(x: 0, y: 0), .right: Point(x: 1, y: 0), .rightMirrored: Point(x: 1, y: 1), .left: Point(x: 0, y: 1),
    ]

    /// Every product is one of the eight and its matrix maps as theirs in turn; up is the identity;
    /// every value has an inverse; composing is associative; rotate and flip reach all eight from up.
    @Test func theEightFormAGroup() {
        let all = Orientation.allCases
        for a in all {
            #expect(a.then(.up) == a && Orientation.up.then(a) == a)
            #expect(all.contains { a.then($0) == .up })
            for b in all {
                for p in [Point(x: 0, y: 0), Point(x: 1, y: 0), Point(x: 0, y: 1)] {
                    #expect(a.then(b).matrix.apply(p) == b.matrix.apply(a.matrix.apply(p)), "\(a) then \(b)")
                }
                for c in all { #expect(a.then(b).then(c) == a.then(b.then(c))) }
            }
        }
        var reached: Set<Orientation> = [.up], frontier: [Orientation] = [.up]
        while let o = frontier.popLast() {
            for next in [o.rotated(clockwise: true), o.flipped(.horizontal), o.flipped(.vertical)] where reached.insert(next).inserted {
                frontier.append(next)
            }
        }
        #expect(reached == Set(all))
    }

    /// Four clockwise turns come back; up turns through right, down and left; ccw undoes cw.
    @Test func fourTurnsAreUp() {
        #expect(Orientation.up.rotated(clockwise: true) == .right)
        #expect(Orientation.right.rotated(clockwise: true) == .down && Orientation.down.rotated(clockwise: true) == .left)
        for o in Orientation.allCases {
            let four = (0..<4).reduce(o) { turned, _ in turned.rotated(clockwise: true) }
            #expect(four == o && o.rotated(clockwise: true).rotated(clockwise: false) == o)
            #expect(o.flipped(.horizontal).flipped(.horizontal) == o && o.flipped(.vertical).flipped(.vertical) == o)
        }
    }

    /// A clockwise turn then a horizontal flip is a vertical flip then the turn, from every value;
    /// a mirrored value turns the other way.
    @Test func turnThenFlipIsFlipThenTurn() {
        for o in Orientation.allCases {
            #expect(o.rotated(clockwise: true).flipped(.horizontal) == o.flipped(.vertical).rotated(clockwise: true), "\(o)")
        }
        #expect(Orientation.upMirrored.rotated(clockwise: true) == .rightMirrored)
        #expect(Orientation.up.flipped(.vertical) == .downMirrored && Orientation.right.flipped(.horizontal) == .leftMirrored)
    }

    /// An odd number of turns swaps the sides; mirrors alone don't.
    @Test func turnedSizeSwaps() {
        #expect(Orientation.right.size(6000, 4000) == (width: 4000, height: 6000))
        for o in Orientation.allCases {
            let swaps: Set<Orientation> = [.right, .left, .rightMirrored, .leftMirrored]
            let s = o.size(6000, 4000)
            #expect(swaps.contains(o) ? s == (4000, 6000) : s == (6000, 4000), "\(o)")
        }
    }

    /// EXIF 1 to 8 map to the eight cases and back, encode as their numbers, and each matrix
    /// moves the top-left corner where EXIF says.
    @Test func exifMapsBothWays() throws {
        let order: [Orientation] = [.up, .upMirrored, .down, .downMirrored, .leftMirrored, .right, .rightMirrored, .left]
        for (i, o) in order.enumerated() {
            #expect(Orientation(rawValue: i + 1) == o && o.rawValue == i + 1)
            #expect(try JSONValue(encoding: o) == .number(Double(i + 1)) && JSONValue.number(Double(i + 1)).decode(Orientation.self) == o)
            #expect(o.matrix.apply(Point(x: 0, y: 0)) == Self.topLeftGoesTo[o], "\(o)")
        }
        #expect(Orientation(rawValue: 0) == nil && Orientation(rawValue: 9) == nil)
    }
}
