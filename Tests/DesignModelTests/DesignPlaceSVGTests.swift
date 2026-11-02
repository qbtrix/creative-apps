// DesignPlaceSVGTests.swift (placed-images PD-2 written, PD-6 turns on): SVG export of a rectangle's or
// frame's picture. PD-6 writes it as a `<clipPath>` of the node's rounded box and an `<image>` at
// `PlaceRules.drawnRect`, after the fill, so the export shows the canvas's crop and never stretches.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import Testing

/// A 1200 × 800 PNG in a 400 × 400 frame with radius 24 at the page origin, its focus at the centre.
private let picture = PlacedAsset(
    id: "asset-1", name: "photo.png", format: .png, natural: Size(width: 1200, height: 800), data: Data([1, 2, 3]))

private let framed = DesignNode(
    id: "node-1", name: "Frame", kind: .frame, frame: rc(0, 0, 400, 400), cornerRadius: 24, placedAsset: picture)

private func svg() -> String { DesignSVG.document([framed], box: rc(0, 0, 400, 400), clip: false) }

@Suite struct DesignPlaceSVGTests {
    @Test
    func imageKeepsAspect() {
        let drawn = PlaceRules.drawnRect(
            PlacedImage(assetID: "asset-1", box: Rect(minX: 0, minY: 0, maxX: 400, maxY: 400)), natural: picture.natural)
        #expect(drawn.width == 600 && drawn.height == 400)
        let text = svg()
        #expect(text.contains("<image"))
        #expect(text.contains("x=\"-100\""))
        #expect(text.contains("width=\"600\" height=\"400\""))
    }

    @Test
    func imageClipsToBox() {
        let text = svg()
        #expect(text.components(separatedBy: "<clipPath").count == 2)
        #expect(text.contains("rx=\"24\""))
        #expect(text.contains("clip-path=\"url(#"))
    }

    @Test
    func aPNGsHrefIsADataURI() {
        #expect(svg().contains("href=\"data:image/png;base64,\(picture.data.base64EncodedString())\""))
    }

    @Test func aRectanglesPictureHasItsOwnClip() {
        let rect = DesignNode(id: "node-2", name: "Photo", kind: .rectangle, frame: rc(10, 10, 400, 400),
                              cornerRadius: 8, placedAsset: picture)
        let lines = DesignSVG.document([rect], box: rc(0, 0, 500, 500), clip: false).split(separator: "\n")
        #expect(lines.contains { $0.contains("<clipPath id=\"pic-node-2\"><rect x=\"10\" y=\"10\"") && $0.contains("rx=\"8\"") })
        let image = lines.first { $0.contains("<image") } ?? ""
        #expect(image.contains("clip-path=\"url(#pic-node-2)\"") && image.contains("x=\"-90\" y=\"10\""))
        let order = lines.map { $0.contains("<image") ? "image" : $0.contains("<rect") && !$0.contains("clipPath") ? "rect" : "" }
        #expect(order.filter { !$0.isEmpty } == ["rect", "image"])
    }

    @Test func aNodeWithoutAPictureWritesNoImage() {
        let plain = DesignNode(id: "node-1", name: "Frame", kind: .frame, frame: rc(0, 0, 400, 400))
        #expect(!DesignSVG.document([plain], box: rc(0, 0, 400, 400), clip: false).contains("<image"))
    }

    @Test func aRectanglesOpacityIsWrittenOnce() {
        let rect = DesignNode(id: "node-2", name: "Photo", kind: .rectangle, frame: rc(0, 0, 400, 400), opacity: 0.5, placedAsset: picture)
        let text = DesignSVG.document([rect], box: rc(0, 0, 400, 400), clip: false)
        #expect(text.components(separatedBy: "opacity=").count == 2)
        #expect(text.contains("<g opacity=\"0.5\">"))
    }

    @Test(arguments: [DesignNodeKind.frame, .rectangle])
    func theStrokeIsWrittenAfterThePictureAtFullWidth(_ kind: DesignNodeKind) {
        let stroked = DesignNode(id: "node-1", name: "Photo", kind: kind, frame: rc(0, 0, 400, 400),
                                 stroke: DesignStroke(color: .black, width: 8), placedAsset: picture)
        let lines = DesignSVG.document([stroked], box: rc(0, 0, 400, 400), clip: false).split(separator: "\n")
        let image = lines.firstIndex { $0.contains("<image") } ?? lines.endIndex
        let strokes = lines.indices.filter { lines[$0].contains("stroke=") }
        #expect(strokes.count == 1 && strokes.allSatisfy { $0 > image })
        // Outside every clip: the line before it closes the picture's group, not a clip still open.
        #expect(strokes.allSatisfy { $0 > image && lines[$0].contains("fill=\"none\"") && !lines[$0].contains("clip-path") && lines[$0 - 1] == lines[image] })
    }

    @Test func aJPEGsAndAnSVGsHrefsNameTheirMediaTypes() {
        let jpeg = PlacedAsset(id: "a", name: "p.jpg", format: .jpeg, natural: Size(width: 2, height: 2), data: Data([1]))
        let vector = PlacedAsset(id: "b", name: "l.svg", format: .svg, natural: Size(width: 2, height: 2), data: Data([2]))
        let nodes = [jpeg, vector].map { DesignNode(id: $0.id, name: $0.name, kind: .rectangle, frame: rc(0, 0, 2, 2), placedAsset: $0) }
        let text = DesignSVG.document(nodes, box: rc(0, 0, 2, 2), clip: false)
        #expect(text.contains("href=\"data:image/jpeg;base64,AQ==\""))
        #expect(text.contains("href=\"data:image/svg+xml;base64,Ag==\""))
    }
}
