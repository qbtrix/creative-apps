// AnchorEditTests.swift (pen-paths PN-1 written, PN-5 turns on): moves, handle drags, insert and remove on a path.
import Testing
import SuiteKernel
@Suite struct AnchorEditTests {
    static func p(_ x: Double, _ y: Double) -> Point { Point(x: x, y: y) }
    /// An open path: a corner, an anchor of `kind` at (100, 0) with handles 30 left and 20 right (40 both sides when
    /// symmetric, since a path measures kind from its handles), a corner.
    static func path(_ kind: AnchorKind = .smooth) -> VectorPath {
        let (h0, h1) = kind == .symmetric ? (60.0, 140.0) : (70.0, 120.0)
        return VectorPath(contours: [VectorContour(anchors: [VectorAnchor(point: p(0, 0)),
            VectorAnchor(point: p(100, 0), handleIn: p(h0, 0), handleOut: p(h1, 0), kind: kind),
            VectorAnchor(point: p(200, 0))], closed: false)])
    }
    static let mid = AnchorRef(contour: 0, index: 1)
    /// The middle anchor after its out handle goes to (100, 20).
    static func dragged(_ kind: AnchorKind = .smooth, breaking: Bool = false) -> VectorAnchor? {
        AnchorEdit.movingHandle(path(kind), mid, .handleOut, to: p(100, 20), breaking: breaking).contours.first?.anchors.dropFirst().first
    }
    @Test func moveCarriesHandles() {
        let a = AnchorEdit.moved(Self.path(), [Self.mid], dx: 5, dy: -5).contours.first?.anchors.dropFirst().first
        #expect(a?.point == Self.p(105, -5) && a?.handleIn == Self.p(75, -5) && a?.handleOut == Self.p(125, -5))
    }
    @Test func smoothKeepsPartner() { #expect(Self.dragged()?.handleIn == Self.p(100, -30)) }
    @Test func symmetricMirrors() { #expect(Self.dragged(.symmetric)?.handleIn == Self.p(100, -20)) }
    @Test func breakingKeepsPartnerPut() {
        #expect(Self.dragged(breaking: true)?.handleIn == Self.p(70, 0) && Self.dragged(breaking: true)?.kind == .corner)
    }
    @Test func insertKeepsOutline() throws {
        let at = try #require(try Self.path().nearest(to: Self.p(150, 0), tolerance: 1))
        let (inserted, ref) = try AnchorEdit.inserting(Self.path(), at: at)
        #expect(ref == AnchorRef(contour: 0, index: 2) && inserted.contours.first?.anchors.count == 4)
        // The flattened outline stays on the original line within 1e-9 (`nearest` itself only settles t to 1e-9).
        let outline = try inserted.flattened(tolerance: 0.01).joined()
        #expect(outline.first == Self.p(0, 0) && outline.last == Self.p(200, 0))
        #expect(outline.allSatisfy { abs($0.y) < 1e-9 && $0.x >= 0 && $0.x <= 200 })
    }
    @Test func removeSeveralInOrder() throws {
        let removed = try AnchorEdit.removing(Self.path(), [AnchorRef(contour: 0, index: 0), Self.mid])
        #expect(removed.contours.first?.anchors.map(\.point) == [Self.p(200, 0)])
    }
}
