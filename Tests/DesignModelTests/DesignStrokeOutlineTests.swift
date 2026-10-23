// DesignStrokeOutlineTests.swift (stroke-style DK-3): the path a layer's stroke paints, before the canvas draws it.
// A rectangle's outline is its rounded box, an ellipse's its ellipse, a shape's its spec's path; text and groups
// have none. `strokedPath` runs that outline through `StrokeRules.paintedPath`: a solid stroke keeps it whole, a
// dashed one breaks it into one subpath per dash, and a stroke with no width paints nothing. Linux-safe.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignStrokeOutlineTests {
    static let box = DesignRect(x: 100, y: 100, width: 200, height: 100)

    static func node(_ kind: DesignNodeKind) -> DesignNode {
        DesignNode(id: "n", name: "N", kind: kind, frame: box)
    }

    static func moves(_ path: VectorPath?) -> Int {
        path?.elements.filter { if case .move = $0 { true } else { false } }.count ?? 0
    }

    @Test func aRectangleTracesItsBox() throws {
        let outline = try #require(Self.node(.rectangle).strokeOutline)
        #expect(outline == (try ShapeRules.path(ShapeSpec(kind: .rectangle), in: Self.box.kernelRect)))
        #expect(Self.node(.ellipse).strokeOutline == (try ShapeRules.path(ShapeSpec(kind: .ellipse), in: Self.box.kernelRect)))
    }

    @Test func aShapeTracesItsSpec() throws {
        var star = Self.node(.shape)
        star.shape = ShapeSpec(kind: .star)
        #expect(star.strokeOutline == star.path(in: Self.box))
        #expect(star.strokeOutline != Self.node(.rectangle).strokeOutline)
    }

    @Test func textAndGroupsHaveNoOutline() {
        #expect(Self.node(.text).strokeOutline == nil)
        #expect(Self.node(.group).strokeOutline == nil)
        #expect(Self.node(.text).strokedPath(VectorStroke(width: 2)) == nil)
    }

    @Test func aSolidStrokeKeepsTheOutlineWhole() {
        let rect = Self.node(.rectangle)
        #expect(rect.strokedPath(VectorStroke(width: 2)) == rect.strokeOutline)
        #expect(Self.moves(rect.strokedPath(VectorStroke(width: 2))) == 1)
    }

    @Test func aDashedStrokeBreaksTheOutline() {
        // A 600 pt perimeter at 8 on, 4 off: 50 dashes.
        let dashed = Self.node(.rectangle).strokedPath(VectorStroke(width: 2, dash: [8, 4]))
        #expect(Self.moves(dashed) >= 40)
    }

    @Test func aStrokeWithNoWidthPaintsNothing() {
        let rect = Self.node(.rectangle)
        #expect(rect.strokedPath(VectorStroke(width: 0)) == nil)
        #expect(rect.strokedPath(VectorStroke(width: .nan)) == nil)
        #expect(rect.strokedPath(VectorStroke(width: 0.5)) != nil)
    }

    @Test func theStrokeColourIsDesigns() {
        #expect(VectorStroke(color: FillColor(r: 1, g: 0, b: 0)).designColor == DesignColor(255, 0, 0))
    }
}
