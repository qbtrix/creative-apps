// DesignStrokeOutlineTests.swift (stroke-style DK-3): the path a layer's stroke paints, before the canvas draws it.
// A rectangle's outline is its rounded box, an ellipse's its ellipse, a shape's its spec's path; text and groups
// have none. `strokedPath` runs that outline through `StrokeRules.paintedPath`: a solid stroke leaves it to the fill's
// shape, a dashed one breaks it into one subpath per dash, and a stroke with no width paints nothing. Linux-safe.
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

    @Test func aRoundedBoxTracesItsCorners() throws {
        let path = { (r: Double) in try ShapeRules.path(ShapeSpec(kind: .rectangle, cornerRadius: r), in: Self.box.kernelRect) }
        for kind in [DesignNodeKind.rectangle, .frame, .instance] {
            let node = DesignNode(id: "n", name: "N", kind: kind, frame: Self.box, cornerRadius: 20)
            #expect(node.strokeOutline == (try path(kind == .instance ? 0 : 20)), "\(kind): an instance has no corners")
        }
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

    @Test func aSolidStrokePaintsTheFillsShape() {
        // nil: the canvas strokes the fill's own outline, so a rounded rect's stroke keeps its corners (#4927).
        let rect = Self.node(.rectangle)
        #expect(rect.strokedPath(VectorStroke(width: 2)) == nil)
        var trimmed = VectorStroke(width: 2)
        trimmed.trim = .init(start: 0, end: 1)
        #expect(rect.strokedPath(trimmed) == nil, "a whole trim paints the outline whole")
        trimmed.trim = .init(start: 0, end: 0.5)
        #expect(Self.moves(rect.strokedPath(trimmed)) == 1)
    }

    @Test func aDottedStrokePaintsItsDots() {
        // A 600 pt perimeter at 0 on, 4 off: 150 dots under a round or square cap (#4925); a butt cap shows none.
        let rect = Self.node(.rectangle)
        for cap in [VectorStroke.Cap.round, .square] {
            #expect(Self.moves(rect.strokedPath(VectorStroke(width: 2, cap: cap, dash: [0, 4]))) >= 140, "\(cap)")
        }
        #expect(Self.moves(rect.strokedPath(VectorStroke(width: 2, cap: .butt, dash: [0, 4]))) == 0)
    }

    @Test func aDashIsCutInViewPoints() throws {
        // At 10x, the dash pattern scales with the outline and each chord stays within the tolerance in view points,
        // so a dashed curve doesn't facet at high zoom (#4926).
        let oval = Self.node(.ellipse), stroke = VectorStroke(width: 2, dash: [8, 4])
        let near = try #require(oval.strokedPath(stroke, scale: 10))
        #expect(Self.moves(near) == Self.moves(oval.strokedPath(stroke)))
        let (cx, cy, rx, ry) = (2000.0, 1500.0, 1000.0, 500.0)
        var at = Point(x: 0, y: 0), worst = 0.0
        for element in near.elements {
            switch element {
            case .move(let p): at = p
            case .line(let p):
                let (x, y) = ((at.x + p.x) / 2, (at.y + p.y) / 2)
                // Distance off the ellipse, roughly: its implicit value times half the smaller radius.
                worst = max(worst, abs(((x - cx) / rx) * ((x - cx) / rx) + ((y - cy) / ry) * ((y - cy) / ry) - 1) * ry / 2)
                at = p
            default: break
            }
        }
        #expect(worst > 0 && worst < 0.5, "chord error \(worst) view points")
    }

    @Test func theDashPhaseScalesWithTheZoom() throws {
        // 40 on, 40 off from phase 40 opens on a gap: the first dash starts 40 pt along the top edge, at (140, 100),
        // which is (280, 200) at 2x. A phase left in document points starts mid-dash at the corner instead (#5010).
        let stroke = VectorStroke(width: 2, dash: [40, 40], dashPhase: 40)
        let first = { (path: VectorPath?) in path?.elements.lazy.compactMap { e -> Point? in
            if case .move(let p) = e { return p } else { return nil }
        }.first }
        let rect = Self.node(.rectangle)
        #expect(first(rect.strokedPath(stroke)) == Point(x: 140, y: 100))
        #expect(first(rect.strokedPath(stroke, scale: 2)) == Point(x: 280, y: 200))
    }

    @Test func aDashedStrokeBreaksTheOutline() {
        // A 600 pt perimeter at 8 on, 4 off: 50 dashes.
        let dashed = Self.node(.rectangle).strokedPath(VectorStroke(width: 2, dash: [8, 4]))
        #expect(Self.moves(dashed) >= 40)
    }

    @Test func aStrokeWithNoWidthPaintsNothing() {
        let rect = Self.node(.rectangle)
        #expect(rect.strokedPath(VectorStroke(width: 0, dash: [8, 4])) == nil)
        #expect(rect.strokedPath(VectorStroke(width: .nan, dash: [8, 4])) == nil)
        #expect(rect.strokedPath(VectorStroke(width: 0.5, dash: [8, 4])) != nil)
    }

    @Test func theStrokeColourIsDesigns() {
        #expect(VectorStroke(color: FillColor(r: 1, g: 0, b: 0)).designColor == DesignColor(255, 0, 0))
    }

    @Test func theStrokePaintsAtItsOpacity() {
        // The canvas paints a stroke at its colour's alpha, as the SVG's stroke-opacity does (#4989).
        let at = { (a: Double) in VectorStroke(color: FillColor(r: 1, g: 0, b: 0, a: a)).designOpacity }
        #expect(at(0.5) == 0.5)
        #expect(at(1) == 1)
        #expect(at(2) == 1)
        #expect(at(-1) == 0)
        #expect(at(.nan) == 1)
    }
}
