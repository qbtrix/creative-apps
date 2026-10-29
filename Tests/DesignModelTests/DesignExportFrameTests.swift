// DesignExportFrameTests.swift: export at a frame (one-document OD-9). An animated document exports the page as
// it shows at `DesignExportOptions.frame`: the raster's artwork is the sampled tree and the SVG differs from the
// rest pose, frame 0 of a document keyed from its rest pose is the rest pose, and a still document's export is
// the same at any frame. The sheet shows its Frame field only for a document with keys. `file.export` takes
// `frame`, and the headless SVG export reads it from its options. Linux-safe.
import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignExportFrameTests {
    private func pageItem(_ w: DesignWorkspace) throws -> DesignExportItem {
        try #require(try w.exportPlan(DesignExportOptions(format: .svg, scope: .page), existing: []).first)
    }

    @Test func anAnimatedPageExportsTheFrameItShows() throws {
        let w = DesignFixtures.animated(50)
        let item = try pageItem(w)
        let page = try #require(w.selectedPage)
        #expect(try w.exportRaster(item, at: 60).artwork.nodes == page.sampled(at: 60).nodes)
        #expect(try w.exportRaster(item).artwork.nodes == page.nodes)
        #expect(try w.exportSVG(item, at: 60) != w.exportSVG(item))
        #expect(try w.exportSVG(item, at: 0) == w.exportSVG(item))
        let frame = try #require(try w.exportPlan(DesignExportOptions(format: .png, scope: .frame), existing: []).first)
        #expect(try w.exportRaster(frame, at: 60) != w.exportRaster(frame), "a child's keys move it inside its frame")
    }

    @Test func aStillDocumentExportsTheSameAtAnyFrame() throws {
        let w = DesignFixtures.cards
        let item = try pageItem(w)
        #expect(try w.exportSVG(item, at: 60) == w.exportSVG(item))
        #expect(try w.exportRaster(item, at: 60) == w.exportRaster(item))
    }

    @Test func theFrameFieldShowsOnlyWithKeys() {
        #expect(!DesignFixtures.cards.exportShowsFrame)
        #expect(DesignFixtures.animated(5).exportShowsFrame)
    }

    @Test func fileExportTakesAFrame() throws {
        var w = DesignFixtures.animated(5)
        let params = JSONValue.object(["format": .string("png"), "scale": .number(1), "scope": .string("page"), "frame": .number(60)])
        _ = try DesignWorkspace.catalog.run("file.export", params: params, on: &w)
    }

    @Test func headlessSVGReadsTheFrame() throws {
        let doc = DesignHeadless(DesignFixtures.animated(5))
        let rest = try doc.export("svg", options: .object([:])).map(\.data)
        #expect(try doc.export("svg", options: .object(["frame": .number(60)])).map(\.data) != rest)
        #expect(try doc.export("svg", options: .object(["frame": .number(0)])).map(\.data) == rest)
    }
}
