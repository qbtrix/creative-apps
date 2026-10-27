// DesignStrokePaintTests.swift (stroke-style DK-3): the canvas strokes `StrokeRules.paintedPath` with the stroke's
// join and cap, read through `vectorStroke`. A white rect (100, 100, 400, 200) with a 6 pt red stroke dashed 40 on,
// 40 off (phase 0, from its top-left corner, clockwise) is red on its top edge at x 120 (a dash) and bare at x 160
// (a gap); solid, both are red. A red line from (100, 400) to (400, 400) stroked 20 pt is red 6 pt past its end
// with a round cap and bare there with a butt one. A node's own stroke still paints solid. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignStrokePaintTests {
    static let red = DesignStroke(color: DesignColor(255, 0, 0), width: 6)

    private func draw(_ node: DesignNode, _ stroke: VectorStroke? = nil) throws -> NSBitmapImageRep {
        let painted = DesignPainted(node: node, backdrop: nil, opacity: 1, stroke: stroke ?? node.vectorStroke)
        return try #require(render(DesignArtwork(painted: [painted], zoom: 1), scheme: .light))
    }

    private func isRed(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) throws -> Bool {
        let c = try #require(image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return c.redComponent > 0.85 && c.greenComponent < 0.15 && c.blueComponent < 0.15
    }

    private var rect: DesignNode {
        DesignNode(id: "r", name: "R", kind: .rectangle, frame: DesignRect(x: 100, y: 100, width: 400, height: 200),
                   fill: DesignColor(255, 255, 255), stroke: Self.red)
    }

    private func line(width: Double) -> DesignNode {
        var node = DesignNode(id: "l", name: "L", kind: .shape, frame: DesignRect(x: 100, y: 390, width: 300, height: 20),
                              fill: DesignColor(255, 255, 255), stroke: DesignStroke(color: DesignColor(255, 0, 0), width: width))
        node.shape = ShapeSpec(kind: .line, start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))
        return node
    }

    @Test func aDashedStrokePaintsGaps() throws {
        var dashed = try #require(rect.vectorStroke)
        dashed.dash = [40, 40]
        let image = try draw(rect, dashed)
        #expect(try isRed(image, 120, 100), "the first dash, 20 pt along the top edge")
        #expect(try !isRed(image, 160, 100), "the first gap, 60 pt along")
        #expect(try isRed(image, 200, 100), "the second dash, 100 pt along")
    }

    @Test func aSolidStrokePaintsWhole() throws {
        let image = try draw(rect)
        #expect(try isRed(image, 120, 100))
        #expect(try isRed(image, 160, 100), "no gap without a dash")
    }

    @Test func aRoundCapRoundsTheEnds() throws {
        let node = line(width: 20)
        var round = try #require(node.vectorStroke)
        round.cap = .round
        #expect(try isRed(draw(node, round), 406, 400), "a round cap reaches half the width past the end")
        #expect(try !isRed(draw(node, round), 408, 409), "but rounds off at the corner")
        #expect(try !isRed(draw(node), 406, 400), "a butt cap stops at the end")
        round.cap = .square
        #expect(try isRed(draw(node, round), 408, 409), "a square cap fills the corner")
    }

    @Test func aMiterJoinSharpensTheCorner() throws {
        var miter = try #require(rect.vectorStroke)
        (miter.width, miter.join) = (20, .miter)
        var bevel = miter
        bevel.join = .bevel
        #expect(try isRed(draw(rect, miter), 508, 308), "the miter tip past the bottom-right corner")
        #expect(try !isRed(draw(rect, bevel), 508, 308), "a bevel cuts it off")
    }

    @Test func aRoundCapRoundsEachDash() throws {
        let node = line(width: 20)
        var dashed = try #require(node.vectorStroke)
        (dashed.dash, dashed.cap) = ([40, 60], .round)
        // The first dash runs 100...140; its round cap reaches 150, the gap runs to 200.
        let image = try draw(node, dashed)
        #expect(try isRed(image, 145, 400), "the cap past the dash")
        #expect(try !isRed(image, 170, 400), "the gap's middle")
    }

    @Test func aDottedStrokePaintsDots() throws {
        // 0 on, 20 off with round caps: a dot every 20 pt along the top edge, bare between (#4925).
        var dotted = try #require(rect.vectorStroke)
        (dotted.cap, dotted.dash) = (.round, [0, 20])
        let image = try draw(rect, dotted)
        #expect(try isRed(image, 120, 100), "a dot")
        #expect(try !isRed(image, 130, 100), "between dots")
    }

    @Test func aHalfClearStrokePaintsHalfClear() throws {
        // A red stroke at alpha 0.5 over the white fill paints pink, as the SVG's stroke-opacity does (#4989).
        var clear = try #require(rect.vectorStroke)
        clear.color.a = 0.5
        let c = try #require(draw(rect, clear).colorAt(x: 300, y: 101)?.usingColorSpace(.sRGB))
        #expect(c.redComponent > 0.85 && (0.35...0.65).contains(c.greenComponent), "pink, not red")
    }
}
#endif
