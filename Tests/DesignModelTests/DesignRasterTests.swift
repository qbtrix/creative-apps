// DesignRasterTests.swift: DesignRaster (design-export DE-8), what a PNG of a planned item draws
// on DesignFixtures.cards: the page item is every node at the page's size; a layer is its own
// subtree moved to the origin (Pair node-6 at (900, 400) holds E1 node-7 and E2 node-8); the
// scale is the plan's pixels over whole points; an unknown id, a size under a point, pixels that
// aren't whole points times one scale, and a side over maxSide are refused. Linux and macOS.
import DesignModel
import Testing

@Suite struct DesignRasterTests {
    let cards = DesignFixtures.cards

    private func item(_ id: String, _ width: Double, _ height: Double, _ pixels: (Int, Int)) -> DesignExportItem {
        DesignExportItem(nodeID: id, fileName: "\(id).png", width: width, height: height,
                         pixelWidth: pixels.0, pixelHeight: pixels.1)
    }

    @Test func thePlansDesktopAtEachScale() throws {
        for scale in 1...3 {
            let planned = try #require(try cards.exportPlan(DesignExportOptions(scale: scale), existing: []).first)
            let raster = try cards.exportRaster(planned)
            #expect(raster.scale == scale)
            #expect(raster.pixelWidth == 1440 * scale && raster.pixelHeight == 1024 * scale)
            #expect(raster.artwork.frameWidth == 1440 && raster.artwork.frameHeight == 1024)
            #expect(raster.artwork.nodes.map(\.id) == ["node-1"])
        }
    }

    @Test func thePageItemIsEveryNode() throws {
        let page = try #require(cards.selectedPage)
        let planned = try #require(try cards.exportPlan(DesignExportOptions(scope: .page), existing: []).first)
        let raster = try cards.exportRaster(planned)
        #expect(raster.artwork.nodes == page.nodes)
        #expect(raster.artwork.frameWidth == page.frameWidth.rounded() && raster.artwork.frameHeight == page.frameHeight.rounded())
    }

    @Test func aLayerIsItsSubtreeAtTheOrigin() throws {
        let raster = try cards.exportRaster(item("node-6", 300, 100, (600, 200)))
        let pair = try #require(raster.artwork.nodes.first)
        #expect(raster.artwork.nodes.count == 1 && pair.id == "node-6")
        #expect(pair.frame == DesignRect(x: 0, y: 0, width: 300, height: 100))
        #expect(pair.children.map(\.frame) == [DesignRect(x: 0, y: 0, width: 100, height: 100),
                                                DesignRect(x: 200, y: 0, width: 100, height: 100)])
        #expect(raster.scale == 2 && raster.artwork.frameWidth == 300 && raster.artwork.frameHeight == 100)
    }

    @Test func refusals() {
        func refusal(_ item: DesignExportItem) -> DesignRasterRefusal? {
            do { _ = try cards.exportRaster(item); return nil } catch { return error }
        }
        #expect(refusal(item("nope", 10, 10, (10, 10))) == .unknownID("nope"))
        #expect(refusal(item("node-3", 0.2, 80, (1, 80))) == .invalidSize)
        #expect(refusal(item("node-3", 200, 80, (400, 80))) == .invalidSize, "two scales")
        #expect(refusal(item("node-3", 200, 80, (300, 120))) == .invalidSize, "not whole points times a scale")
        #expect(refusal(item("node-3", 200, 80, (0, 0))) == .invalidSize)
        #expect(refusal(item("node-3", 16_385, 80, (16_385, 80))) == .invalidSize)
        #expect(refusal(item("node-3", 200, 16_385, (200, 16_385))) == .invalidSize)
        #expect(refusal(item("node-3", 16_384, 80, (16_384, 80))) == nil, "maxSide itself draws")
        #expect(refusal(item("node-3", .nan, 80, (200, 80))) == .invalidSize)
    }
}
