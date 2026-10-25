// DesignPlaceSnapshots.swift (placed-images PD-u, PD-3): Design's pictures on the canvas, drawn by cover
// through SuiteUI's drawPlaced in DesignArtwork's Canvas, over the fill and under the stroke. A 1200 × 800
// chart (a grid, a centred circle, a corner square) fitted at its own shape, the same chart in a 400 × 400
// frame with radius 24 (cropped, the circle still round, and rounded), and an SVG logo in a rectangle. Writes design-image-fitted-, design-image-in-frame- and
// design-image-svg-{light,dark}.png. `DesignPlaceSeed` is the document RenderBudgetDesignPlaceTests and the
// Image section's snapshots drive too. macOS only.
import AppKit
import ImageIO
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import DesignApp
@testable import DesignModel

/// Pages of pictures, as a file holding them opens.
enum DesignPlaceSeed {
    /// A `width` × `height` JPEG named "photo-<width>x<height>.jpg" (`chart`).
    static func photo(width: Int = 1200, height: Int = 800) throws -> PlacedAsset {
        PlacedAsset(id: "photo-\(width)x\(height)", name: "photo-\(width)x\(height).jpg", format: .jpeg,
                    natural: Size(width: Double(width), height: Double(height)), data: try chart(width: width, height: height))
    }

    /// A 6 × 4 grid of white lines on blue, a red circle half the height across in the middle and a yellow
    /// square in the top-left cell: a stretch turns the circle oval, a cover crop cuts the outer columns and
    /// leaves it round, and the square shows which way up the picture is.
    static func chart(width: Int, height: Int) throws -> Data {
        let data = NSMutableData(), (w, h) = (CGFloat(width), CGFloat(height))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw CocoaError(.fileWriteUnknown) }
        context.setFillColor(CGColor(srgbRed: 0.1, green: 0.3, blue: 0.7, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: w, height: h))
        context.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        context.setLineWidth(max(h / 100, 1))
        context.strokeLineSegments(between: (0...6).flatMap { i -> [CGPoint] in let x = CGFloat(i) * w / 6; return [CGPoint(x: x, y: 0), CGPoint(x: x, y: h)] })
        context.strokeLineSegments(between: (0...4).flatMap { i -> [CGPoint] in let y = CGFloat(i) * h / 4; return [CGPoint(x: 0, y: y), CGPoint(x: w, y: y)] })
        context.setFillColor(CGColor(srgbRed: 0.9, green: 0.1, blue: 0.1, alpha: 1))
        context.fillEllipse(in: CGRect(x: w / 2 - h / 4, y: h / 4, width: h / 2, height: h / 2))
        context.setFillColor(CGColor(srgbRed: 1, green: 0.8, blue: 0, alpha: 1))  // CG's origin is bottom-left
        context.fill(CGRect(x: w / 24, y: h - h / 16 - h / 8, width: h / 8, height: h / 8))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return data as Data
    }

    /// `node` showing `asset` on an 800 × 600 page, selected.
    static func page(_ node: DesignNode) -> DesignWorkspace {
        var model = DesignFixtures.cards
        model.useServices(.live)
        model.load([DesignPage(id: "page-1", name: "Page 1", frameWidth: 800, frameHeight: 600, nodes: [node])])
        model.selectItem(node.id)
        return model
    }

    /// node-1, a 400 × 400 frame at (100, 100) with radius 24, showing the photo.
    static func framed() throws -> DesignWorkspace {
        try page(DesignNode(id: "node-1", name: "Frame", kind: .frame, frame: DesignRect(x: 100, y: 100, width: 400, height: 400),
                            cornerRadius: 24, placedAsset: photo()))
    }
}

@MainActor
@Suite struct DesignPlaceSnapshots {
    private func shoot(_ view: some View, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// `node` alone on the canvas's paint at 100%.
    private func art(_ node: DesignNode) -> some View {
        DesignArtwork(painted: [DesignPainted(node: node, backdrop: nil, opacity: 1)], zoom: 1)
            .frame(width: 800, height: 600).background(SuiteColor.canvasSurround)
    }

    @Test func fitted() throws {
        let node = DesignNode(id: "node-1", name: "photo-1200x800", kind: .rectangle,
                              frame: DesignRect(x: 100, y: 100, width: 600, height: 400), placedAsset: try DesignPlaceSeed.photo())
        #expect(node.placedImage?.box == Rect(minX: 100, minY: 100, maxX: 700, maxY: 500))
        try shoot(art(node), "design-image-fitted")
    }

    @Test func inFrame() throws {
        let node = try #require(try DesignPlaceSeed.framed().selectedNode)
        #expect(node.placedImage.map { PlaceRules.drawnRect($0, natural: Size(width: 1200, height: 800)).width } == 600)
        try shoot(art(node), "design-image-in-frame")
    }

    @Test func svg() throws {
        var node = DesignNode(id: "node-1", name: "logo", kind: .rectangle, frame: DesignRect(x: 160, y: 220, width: 480, height: 160),
                              cornerRadius: 12, placedAsset: HaloPlaceSnapshots.logoAsset)
        node.stroke = DesignStroke(color: DesignColor(28, 28, 30), width: 2)
        #expect(node.placedAsset?.format == .svg)
        try shoot(art(node), "design-image-svg")
    }
}
