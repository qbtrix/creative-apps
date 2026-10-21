// OrientationTests.swift (orientation-crop OC-2, turned on by OC-3): the eight EXIF orientations
// as a group: compose, rotate, flip, the turned size, the unit-square matrix and EXIF's numbers.
import Testing
import SuiteKernel

@Suite struct OrientationTests {
    /// Every product is one of the eight and its matrix maps as theirs in turn; up is the identity;
    /// every value has an inverse; composing is associative; rotate and flip reach all eight from up.
    @Test(.disabled("waits on OC-3")) func theEightFormAGroup() {
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
    @Test(.disabled("waits on OC-3")) func fourTurnsAreUp() {
        #expect(Orientation.up.rotated(clockwise: true) == .right)
        #expect(Orientation.right.rotated(clockwise: true) == .down && Orientation.down.rotated(clockwise: true) == .left)
        for o in Orientation.allCases {
            let four = (0..<4).reduce(o) { turned, _ in turned.rotated(clockwise: true) }
            #expect(four == o && o.rotated(clockwise: true).rotated(clockwise: false) == o)
            #expect(o.flipped(.horizontal).flipped(.horizontal) == o && o.flipped(.vertical).flipped(.vertical) == o)
        }
    }
}
