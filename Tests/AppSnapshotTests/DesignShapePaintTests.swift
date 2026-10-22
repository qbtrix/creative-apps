// DesignShapePaintTests.swift (shape-tools DS-3): the canvas paints a shape node's path, the spec's
// `DesignNode.path(in:)`, in its frame, not its box. A red five-point star in (100, 100, 200, 200), drawn
// alone by DesignArtwork at 100%, is red below its top tip and at its centre and bare in its box's top-left
// corner. Stretched to 400 wide it redraws: red just inside its new right tip, past where the old box ended,
// and its corner still bare. A red arrow is stroked only: red on its shaft, bare beside it inside its box. A
// star whose spec can't be drawn (2 points) paints its box. These pass once DS-5 builds `path(in:)`; until
// then the stub's nil paints the box. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignShapePaintTests {
    private func shape(_ spec: ShapeSpec, _ frame: DesignRect, stroke: DesignStroke? = nil) -> DesignNode {
        var node = DesignNode(id: "s", name: "S", kind: .shape, frame: frame, fill: DesignColor(255, 0, 0), stroke: stroke)
        node.shape = spec
        return node
    }

    private func draw(_ node: DesignNode) throws -> NSBitmapImageRep {
        let artwork = DesignArtwork(painted: [DesignPainted(node: node, backdrop: nil, opacity: 1)], zoom: 1)
        return try #require(render(artwork, scheme: .light))
    }

    private func isRed(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) throws -> Bool {
        let c = try #require(image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return c.redComponent > 0.85 && c.greenComponent < 0.15 && c.blueComponent < 0.15
    }

    @Test func aStarPaintsItsPathNotItsBox() throws {
        let star = shape(ShapeSpec(kind: .star), DesignRect(x: 100, y: 100, width: 200, height: 200))
        let image = try draw(star)
        #expect(try isRed(image, 200, 112), "below the top tip (200, 100)")
        #expect(try isRed(image, 200, 200), "at the centre")
        #expect(try !isRed(image, 108, 108), "the box's top-left corner is outside the star")
        #expect(try !isRed(image, 292, 292), "and so is its bottom-right")
    }

    @Test func aResizeRedrawsTheStar() throws {
        var star = shape(ShapeSpec(kind: .star), DesignRect(x: 100, y: 100, width: 200, height: 200))
        #expect(try !isRed(draw(star), 470, 170), "past the box before the resize")
        star.frame = DesignRect(x: 100, y: 100, width: 400, height: 200)
        let image = try draw(star)
        // The right tip sits 18° above the centre's level: (300 + 200 cos 18°, 200 − 100 sin 18°) = (490, 169).
        #expect(try isRed(image, 470, 170), "inside the stretched right tip")
        #expect(try isRed(image, 300, 200), "at the new centre")
        #expect(try !isRed(image, 108, 108), "the corner stays bare")
    }

    @Test func anArrowIsStrokedOnly() throws {
        let spec = ShapeSpec(kind: .arrow, start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))
        let arrow = shape(spec, DesignRect(x: 100, y: 300, width: 300, height: 40),
                          stroke: DesignStroke(color: DesignColor(255, 0, 0), width: 4))
        let image = try draw(arrow)
        #expect(try isRed(image, 150, 320), "on the shaft")
        #expect(try !isRed(image, 150, 306), "beside the shaft, inside the box: no fill")
    }

    @Test func aSpecThatCantDrawPaintsItsBox() throws {
        let star = shape(ShapeSpec(kind: .star, points: 2), DesignRect(x: 100, y: 100, width: 200, height: 200))
        #expect(star.path(in: star.frame) == nil)
        #expect(try isRed(draw(star), 108, 108), "the box, as before shapes drew")
    }
}
#endif
