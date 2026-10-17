// DesignArtworkPathTests.swift: the canvas artwork draws each layer as stored (style-rows ST-5,
// QD-V3). A rounded rectangle's and an ellipse's built Path hold curve elements, never only
// lines; a frame at 50% opacity fades its children; a 4 pt stroke draws centered on the edge,
// scaled with the zoom. The geometry is DesignCanvasMarks' artworkPath and artworkStroke, and the
// opacity is DesignPage.painted, the same values DesignArtwork draws from. macOS only.
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignArtworkPathTests {
    private let box = DesignRect(x: 100, y: 50, width: 200, height: 120)

    /// Whether `path` holds a cubic or quadratic curve, and how many elements it has.
    private func curves(in path: Path) -> (curves: Int, elements: Int) {
        var curves = 0
        var elements = 0
        path.forEach { element in
            elements += 1
            switch element {
            case .curve, .quadCurve: curves += 1
            case .move, .line, .closeSubpath: break
            }
        }
        return (curves, elements)
    }

    @Test func aRoundedRectangleKeepsItsCurves() throws {
        let node = DesignNode(id: "r", name: "R", kind: .rectangle, frame: box, cornerRadius: 16)
        let path = try #require(artworkPath(for: node, scale: 1))
        let counted = curves(in: path)
        #expect(counted.curves >= 4, "four rounded corners, got \(counted.curves) curves of \(counted.elements)")
    }

    @Test func aRoundedFrameKeepsItsCurvesAtAnyZoom() throws {
        let node = DesignNode(id: "f", name: "F", kind: .frame, frame: box, cornerRadius: 24)
        for zoom in [0.25, 1, 2] {
            let path = try #require(artworkPath(for: node, scale: zoom))
            #expect(curves(in: path).curves >= 4, "zoom \(zoom)")
        }
    }

    @Test func anEllipseKeepsItsCurves() throws {
        let node = DesignNode(id: "e", name: "E", kind: .ellipse, frame: box)
        let path = try #require(artworkPath(for: node, scale: 1))
        #expect(curves(in: path).curves >= 4)
    }

    @Test func aSquareRectangleIsItsBox() throws {
        let node = DesignNode(id: "r", name: "R", kind: .rectangle, frame: box)
        let path = try #require(artworkPath(for: node, scale: 2))
        #expect(path.boundingRect.equalTo(CGRect(x: 200, y: 100, width: 400, height: 240)))
    }

    @Test func textAndGroupsHaveNoShape() {
        #expect(artworkPath(for: DesignNode(id: "t", name: "T", kind: .text, frame: box), scale: 1) == nil)
        #expect(artworkPath(for: DesignNode(id: "g", name: "G", kind: .group, frame: box), scale: 1) == nil)
    }

    @Test func aFrameAtHalfOpacityFadesItsChildren() {
        let child = DesignNode(id: "child", name: "Child", kind: .rectangle, frame: box)
        let faint = DesignNode(id: "faint", name: "Faint", kind: .ellipse, frame: box, opacity: 0.5)
        let frame = DesignNode(
            id: "frame", name: "Frame", kind: .frame, frame: DesignRect(x: 0, y: 0, width: 400, height: 300),
            children: [child, faint], opacity: 0.5)
        let sibling = DesignNode(id: "sibling", name: "Sibling", kind: .rectangle, frame: box)
        let page = DesignPage(id: "p", name: "P", frameWidth: 800, frameHeight: 600, nodes: [frame, sibling])
        let opacity = Dictionary(uniqueKeysWithValues: page.painted.map { ($0.id, $0.opacity) })
        #expect(opacity == ["frame": 0.5, "child": 0.5, "faint": 0.25, "sibling": 1])
    }

    @Test func anOpacityOutOfRangeDrawsWithinIt() {
        #expect(drawnOpacity(-1) == 0)
        #expect(drawnOpacity(3) == 1)
        #expect(drawnOpacity(.nan) == 1)
        #expect(drawnOpacity(0.4) == 0.4)
    }

    @Test func aFourPointStrokeDrawsCenteredOnTheEdge() throws {
        let node = DesignNode(
            id: "r", name: "R", kind: .rectangle, frame: box, stroke: DesignStroke(color: .black, width: 4))
        for zoom in [1.0, 2.0] {
            let path = try #require(artworkPath(for: node, scale: zoom))
            let style = try #require(artworkStroke(for: node, scale: zoom))
            #expect(Double(style.lineWidth) == 4 * zoom)
            let drawn = path.strokedPath(style).boundingRect
            let edge = path.boundingRect
            // Half the width outside the edge on every side, so half lies inside.
            let half = 2 * zoom
            #expect(abs(drawn.minX - (edge.minX - half)) < 0.01, "zoom \(zoom)")
            #expect(abs(drawn.minY - (edge.minY - half)) < 0.01, "zoom \(zoom)")
            #expect(abs(drawn.maxX - (edge.maxX + half)) < 0.01, "zoom \(zoom)")
            #expect(abs(drawn.maxY - (edge.maxY + half)) < 0.01, "zoom \(zoom)")
        }
    }

    @Test func noStrokeOrAZeroWidthDrawsNone() {
        let bare = DesignNode(id: "r", name: "R", kind: .rectangle, frame: box)
        let zero = DesignNode(
            id: "z", name: "Z", kind: .rectangle, frame: box, stroke: DesignStroke(color: .black, width: 0))
        #expect(artworkStroke(for: bare, scale: 1) == nil)
        #expect(artworkStroke(for: zero, scale: 1) == nil)
    }
}
