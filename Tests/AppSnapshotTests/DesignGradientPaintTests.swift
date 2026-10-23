// DesignGradientPaintTests.swift (gradient-fill DG-3): the canvas artwork paints a node's gradient,
// not its solid colour. A 200 × 100 rectangle with a red-to-blue linear gradient across its unit box,
// drawn alone by DesignArtwork at 100% in a hosted render, is red at its left edge and blue at its
// right; a radial one is its first stop at the centre and its last at a corner. Text takes the same
// shading as its foreground: a red-to-blue line of text, clipped at its 400 pt box, paints both red and blue
// ink. The PNG and PDF exports draw through the same DesignArtwork. macOS only.
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignGradientPaintTests {
    static let red = FillColor(r: 1, g: 0, b: 0), blue = FillColor(r: 0, g: 0, b: 1)
    static let stops = [GradientStop(offset: 0, color: red), GradientStop(offset: 1, color: blue)]
    static let across = Fill.linear(stops: stops, start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))

    /// `node` drawn alone by the canvas artwork at 100%, one pixel per page point.
    private func draw(_ node: DesignNode) throws -> NSBitmapImageRep {
        let artwork = DesignArtwork(painted: [DesignPainted(node: node, backdrop: nil, opacity: 1)], zoom: 1)
        return try #require(render(artwork, scheme: .light))
    }

    /// The sRGB channels of pixel (x, y), 0...1.
    private func rgb(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) throws -> (Double, Double, Double) {
        let color = try #require(image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB))
        return (color.redComponent, color.greenComponent, color.blueComponent)
    }

    private func isRed(_ c: (Double, Double, Double)) -> Bool { c.0 > 0.85 && c.1 < 0.15 && c.2 < 0.15 }
    private func isBlue(_ c: (Double, Double, Double)) -> Bool { c.0 < 0.15 && c.1 < 0.15 && c.2 > 0.85 }

    @Test func aLinearGradientPaintsItsStopsAtItsEdges() throws {
        let frame = DesignRect(x: 100, y: 100, width: 200, height: 100)
        let node = DesignNode(id: "r", name: "R", kind: .rectangle, frame: frame, gradient: Self.across)
        let image = try draw(node)
        let left = try rgb(image, 102, 150), right = try rgb(image, 297, 150)
        #expect(isRed(left), "left edge is the first stop, got \(left)")
        #expect(isBlue(right), "right edge is the last stop, got \(right)")
    }

    @Test func aRadialGradientPaintsItsFirstStopAtTheCentre() throws {
        let radial = Fill.radial(stops: Self.stops, center: Point(x: 0.5, y: 0.5), radius: 0.5)
        let frame = DesignRect(x: 100, y: 100, width: 200, height: 200)
        let image = try draw(DesignNode(id: "r", name: "R", kind: .rectangle, frame: frame, gradient: radial))
        let centre = try rgb(image, 200, 200), corner = try rgb(image, 102, 102)
        #expect(isRed(centre), "centre is the first stop, got \(centre)")
        #expect(isBlue(corner), "past the radius is the last stop, got \(corner)")
    }

    @Test func textTakesTheGradientAsItsForeground() throws {
        var style = DesignTextStyle.default
        style.size = 64
        let frame = DesignRect(x: 100, y: 100, width: 400, height: 120)
        let node = DesignNode(
            id: "t", name: "T", kind: .text, frame: frame, text: "MMMMMMMMMMMM", textStyle: style, gradient: Self.across)
        let image = try draw(node)
        var (reds, blues) = (0, 0)
        for y in 100..<220 {
            for x in 100..<500 {
                let c = try rgb(image, x, y)
                if isRed(c) { reds += 1 } else if isBlue(c) { blues += 1 }
            }
        }
        #expect(reds > 50, "red ink near the start, got \(reds) px")
        #expect(blues > 50, "blue ink near the end, got \(blues) px")
    }
}
