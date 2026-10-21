// TransformRulesTests.swift (transform-tools TT-1 shape, TT-5 body): the turn, flip and scale
// rules on a TransformBox, run on TT-5's bodies.
import Testing
import SuiteKernel

@Suite struct TransformRulesTests {
    static let wide = TransformBox(box: Rect(minX: 0, minY: 0, maxX: 100, maxY: 50))
    static func near(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }
    static func near(_ a: Point, _ b: Point) -> Bool { near(a.x, b.x) && near(a.y, b.y) }

    /// The contract's words: nine anchors, two flip directions, a box with no turn and no mirrors by default.
    @Test func contractShape() {
        #expect(BoxAnchor.allCases.map(\.rawValue) == ["topLeft", "top", "topRight", "left", "center", "right",
                                                         "bottomLeft", "bottom", "bottomRight"])
        #expect(FlipDirection.allCases.map(\.rawValue) == ["horizontal", "vertical"])
        let t = Self.wide; #expect(t.degrees == 0 && t.flipX == false && t.flipY == false && t.box.width == 100)
    }

    /// A turn lands in (-180, 180]: 190 is -170, -180 is 180, a whole turn is 0.
    @Test func normalizesHalfTurn() {
        #expect(Self.near(TransformRules.normalized(190), -170))
        #expect(Self.near(TransformRules.normalized(180), 180) && Self.near(TransformRules.normalized(-180), 180))
        #expect(Self.near(TransformRules.normalized(720), 0) && Self.near(TransformRules.normalized(-90), -90))
        #expect(Self.near(TransformRules.rotated(Self.wide, by: 270).degrees, -90))
    }

    /// A 100 × 50 box turned 90° clockwise about (50, 25): its corners, clockwise from the turned top-left.
    @Test func cornersTurn90() {
        let turned = TransformRules.rotated(Self.wide, by: 90)
        let expected = [Point(x: 75, y: -25), Point(x: 75, y: 75), Point(x: 25, y: 75), Point(x: 25, y: -25)]
        let corners = TransformRules.corners(of: turned)
        #expect(corners.count == 4 && zip(corners, expected).allSatisfy { Self.near($0, $1) })
        let b = TransformRules.bounds(of: turned)
        #expect(Self.near(b.width, 50) && Self.near(b.height, 100))
    }

    /// A square turned 45° has bounds √2 wider, about the same centre.
    @Test func boundsOfTurnedSquare() {
        let square = TransformBox(box: Rect(minX: 0, minY: 0, maxX: 100, maxY: 100), degrees: 45)
        let b = TransformRules.bounds(of: square)
        #expect(Self.near(b.width, 100 * 2.0.squareRoot()) && Self.near(b.height, 100 * 2.0.squareRoot()))
        #expect(Self.near((b.minX + b.maxX) / 2, 50) && Self.near((b.minY + b.maxY) / 2, 50))
    }

    /// `local` undoes `matrix`: a point of the unturned box, sent to the document, comes back where it was.
    @Test func localInvertsMatrix() {
        let t = TransformBox(box: Rect(minX: 10, minY: 20, maxX: 110, maxY: 70), degrees: 30, flipX: true)
        for (u, v) in [(0.0, 0.0), (1.0, 0.0), (0.25, 0.75), (1.0, 1.0)] {
            let p = Point(x: 10 + u * 100, y: 20 + v * 50)
            #expect(Self.near(TransformRules.local(TransformRules.matrix(of: t).apply(Point(x: u, y: v)), in: t), p))
        }
        #expect(Self.near(TransformRules.matrix(of: Self.wide).apply(Point(x: 1, y: 1)), Point(x: 100, y: 50)))
    }

    /// A flip mirrors the box in place: the centre stays and the turn is negated; flipping twice is no change.
    @Test func flipKeepsCentre() {
        let t = TransformBox(box: Rect(minX: 0, minY: 0, maxX: 100, maxY: 50), degrees: 30)
        let flipped = TransformRules.flipped(t, .horizontal)
        #expect(flipped.flipX && !flipped.flipY && Self.near(flipped.degrees, -30) && flipped.box == t.box)
        let (before, after) = (TransformRules.bounds(of: t), TransformRules.bounds(of: flipped))
        #expect(Self.near(before.minX + before.maxX, after.minX + after.maxX) && Self.near(before.minY + before.maxY, after.minY + after.maxY))
        #expect(TransformRules.flipped(TransformRules.flipped(t, .vertical), .vertical) == t)
    }

    /// Scale about an anchor keeps that anchor's point: 2 × about the bottom-right keeps (100, 50).
    @Test func scaleKeepsAnchor() {
        let s = TransformRules.scaled(Self.wide, sx: 2, sy: 2, about: .bottomRight)
        #expect(s.box == Rect(minX: -100, minY: -50, maxX: 100, maxY: 50))
        #expect(TransformRules.scaled(Self.wide, sx: 0.5, sy: 1, about: .center).box == Rect(minX: 25, minY: 0, maxX: 75, maxY: 50))
    }

    /// On a turned box the anchor's document point stays put, and a factor that isn't above 0 changes nothing.
    @Test func turnedScaleKeepsAnchorPoint() {
        let t = TransformBox(box: Rect(minX: 0, minY: 0, maxX: 100, maxY: 50), degrees: 30, flipY: true)
        let s = TransformRules.scaled(t, sx: 1.5, sy: 3, about: .topRight)
        #expect(Self.near(s.box.width, 150) && Self.near(s.box.height, 150) && s.degrees == 30 && s.flipY)
        let unit = Point(x: 1, y: 0)
        #expect(Self.near(TransformRules.matrix(of: s).apply(unit), TransformRules.matrix(of: t).apply(unit)))
        #expect(TransformRules.scaled(t, sx: 0, sy: 1, about: .center) == t && TransformRules.scaled(t, sx: -1, sy: 1, about: .top) == t)
    }

    /// A turn by a non-finite amount leaves the box as it was.
    @Test func nonFiniteTurnIsNoChange() {
        #expect(TransformRules.rotated(Self.wide, by: .nan) == Self.wide && TransformRules.rotated(Self.wide, by: .infinity) == Self.wide)
    }

    /// Canvas Size: a 200 px border around 400 × 300 content puts it at (100, 100) about the centre.
    @Test func anchoredCentre() {
        let (old, new) = ((w: 400.0, h: 300.0), (w: 600.0, h: 500.0))
        #expect(Self.near(TransformRules.anchoredOrigin(old: old, new: new, .center), Point(x: 100, y: 100)))
        #expect(Self.near(TransformRules.anchoredOrigin(old: old, new: new, .topLeft), Point(x: 0, y: 0)))
        #expect(Self.near(TransformRules.anchoredOrigin(old: old, new: new, .bottomRight), Point(x: 200, y: 200)))
        #expect(Self.near(TransformRules.anchoredOrigin(old: old, new: new, .right), Point(x: 200, y: 100)))
    }
}
