// DesignRasterizerTests.swift: design-export DE-8, the PNG half of DE-w. DesignRasterizer.png
// of an item the Model's plan names: `cards`' Desktop frame is 1440 × 1024 px at 1x, 2880 × 2048
// at 2x and 4320 × 3072 at 3x, and the `twoPages` Mobile page is 390 × 844; a layer's PNG is its
// own box, its fill at the middle; on a page with one shape, the corner where nothing is drawn
// has alpha 0 and the shape is opaque; and QD-V9, the 2x Desktop PNG against the canvas's own
// artwork drawn by the golden host, is report-only until #331 and #332. macOS only.
#if canImport(AppKit)
import AppKit
import ImageIO
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignRasterizerTests {
    /// The one item `options` plans on `model`'s selected page.
    private func item(_ model: DesignWorkspace, _ options: DesignExportOptions) throws -> DesignExportItem {
        let items = try model.exportPlan(options, existing: [])
        #expect(items.count == 1)
        return try #require(items.first)
    }

    /// The pixel size ImageIO reads from `png`'s first image.
    private func readSize(_ png: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    /// The RGBA channels of pixel (x, y), top row first; empty outside the image.
    private func pixel(_ image: RGBAImage, x: Int, y: Int) -> [Int] {
        let at = (y * image.width + x) * 4
        guard x >= 0, y >= 0, x < image.width, at + 4 <= image.bytes.count else { return [] }
        return image.bytes[at..<at + 4].map(Int.init)
    }

    private func near(_ got: [Int], _ want: [Int], within: Int = 2) -> Bool {
        got.count == want.count && zip(got, want).allSatisfy { abs($0 - $1) <= within }
    }

    @Test func pixelSize() throws {
        let cards = DesignFixtures.cards
        for (scale, size) in [(1, (1440, 1024)), (2, (2880, 2048)), (3, (4320, 3072))] {
            let desktop = try item(cards, DesignExportOptions(format: .png, scale: scale, scope: .frame))
            #expect(desktop.nodeID == "node-1" && desktop.pixelWidth == size.0 && desktop.pixelHeight == size.1)
            let page = try #require(cards.selectedPage)
            let png = try DesignRasterizer.png(desktop, on: page, scale: scale)
            #expect(png.starts(with: [0x89, 0x50, 0x4E, 0x47]), "a PNG signature")
            let read = try #require(readSize(png))
            #expect(read.width == size.0 && read.height == size.1, "\(scale)x is \(read)")
        }
        var two = DesignFixtures.twoPages
        two.selectPage("page-2")
        let mobile = try item(two, DesignExportOptions(format: .png, scale: 1, scope: .page))
        let png = try DesignRasterizer.png(mobile, on: try #require(two.selectedPage), scale: 1)
        let read = try #require(readSize(png))
        #expect(read.width == 390 && read.height == 844, "Mobile is \(read)")
    }

    /// A layer's PNG is its own box, moved to the origin: B (200 × 80) is its gray fill corner to corner.
    @Test func aLayerIsItsOwnBox() throws {
        let page = try #require(DesignFixtures.cards.selectedPage)
        let b = DesignExportItem(nodeID: "node-3", fileName: "B.png", width: 200, height: 80, pixelWidth: 400, pixelHeight: 160)
        let image = try #require(RGBAImage(png: try DesignRasterizer.png(b, on: page, scale: 2)))
        #expect(image.width == 400 && image.height == 160)
        for (x, y) in [(2, 2), (200, 80), (397, 157)] {
            #expect(near(pixel(image, x: x, y: y), [217, 217, 217, 255]), "B at (\(x), \(y)): \(pixel(image, x: x, y: y))")
        }
        let missing = DesignExportItem(nodeID: "nope", fileName: "x.png", width: 1, height: 1, pixelWidth: 1, pixelHeight: 1)
        #expect(throws: DesignRasterizerError.noSuchItem("nope")) { try DesignRasterizer.png(missing, on: page, scale: 1) }
    }

    /// One shape on a bare 200 × 100 page: the corners hold nothing and stay transparent.
    @Test func alphaOutsideShapes() throws {
        let shape = DesignNode(id: "r", name: "R", kind: .rectangle, frame: DesignRect(x: 50, y: 25, width: 100, height: 50))
        let page = DesignPage(id: "p", name: "P", frameWidth: 200, frameHeight: 100, nodes: [shape])
        let item = DesignExportItem(nodeID: "p", fileName: "P.png", width: 200, height: 100, pixelWidth: 200, pixelHeight: 100)
        let image = try #require(RGBAImage(png: try DesignRasterizer.png(item, on: page, scale: 1)))
        #expect(image.width == 200 && image.height == 100)
        for (x, y) in [(0, 0), (199, 0), (0, 99), (199, 99), (20, 50)] {
            #expect(pixel(image, x: x, y: y).last == 0, "(\(x), \(y)) is \(pixel(image, x: x, y: y))")
        }
        #expect(near(pixel(image, x: 100, y: 50), [217, 217, 217, 255]), "the shape: \(pixel(image, x: 100, y: 50))")
    }

    /// QD-V9: the 2x Desktop PNG is the canvas's artwork of that frame. Report-only until #331 and #332.
    @Test func matchesCanvasGolden() throws {
        let cards = DesignFixtures.cards
        let page = try #require(cards.selectedPage)
        let desktop = try item(cards, DesignExportOptions(format: .png, scale: 2, scope: .frame))
        let png = try #require(RGBAImage(png: try DesignRasterizer.png(desktop, on: page, scale: 2)))
        let canvas = try #require(SnapshotHost(appearance: .light).image(
            DesignArtwork(painted: page.painted, zoom: 1), size: CGSize(width: 1440, height: 1024)))
        let result = GoldenImage().compare(png, to: canvas, tolerance: .standard)
        print("QD-V9 design-raster-desktop: \(result.differing) pixels differ, share \(result.share)")
        if !result.passes {
            withKnownIssue("QD-V9 is report-only until #331 and #332", isIntermittent: true) {
                Issue.record("the 2x Desktop PNG differs from the canvas: \(result.differing) pixels, share \(result.share)")
            }
        }
    }
}
#endif
