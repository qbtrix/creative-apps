// HaloHeadlessTextTests.swift (#5280): HaloHeadless made or opened on the caller's services draws its text layers with
// that text rasterizer, so a host holding Core Text (the CLI and MCP, once they can reach it) passes it in and a
// `text.set` then export has the words in it. `.live` carries no text rasterizer; HaloModel can't reach Core Text.
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

/// `.live` with the fake rasterizer for text, which draws a box in the layer's colour.
private var textServices: HaloServices {
    var services = HaloServices.live
    services.text = FakeTextRasterizer()
    return services
}

/// The PNG export of `doc` at frame 0.
private func frameZero(_ doc: HaloHeadless) throws -> Data {
    try #require(doc.export("png", options: .object(["frame": .number(0)])).first).data
}

/// Adds a text layer reading "Hello" at 120 pt and returns the export before and after.
private func exportsAroundText(_ doc: inout HaloHeadless) throws -> (before: Data, after: Data) {
    let before = try frameZero(doc)
    _ = try HaloHeadless.catalog.run("layer.new", params: .object(["kind": .string("text")]), on: &doc)
    _ = try HaloHeadless.catalog.run("text.set", params: .object(["text": .string("Hello")]), on: &doc)
    _ = try HaloHeadless.catalog.run("text.set-size", params: .object(["size": .number(120)]), on: &doc)
    return (before, try frameZero(doc))
}

@Suite struct HaloHeadlessTextTests {
    @Test func aNewDocumentDrawsTextWithTheCallersRasterizer() throws {
        var doc = try HaloHeadless.new(.object(["width": .number(320), "height": .number(180)]), services: textServices)
        #expect(doc.workspace.services.text is FakeTextRasterizer)
        let png = try exportsAroundText(&doc)
        #expect(png.after != png.before, "the text layer left the export unchanged")
    }

    @Test func anOpenedFileDrawsTextWithTheCallersRasterizer() throws {
        let data = try HaloHeadlessTests.input("place-logo", "empty-400.halo")
        var doc = try HaloHeadless.open(data, name: "empty-400.halo", services: textServices)
        #expect(doc.workspace.services.text is FakeTextRasterizer)
        let png = try exportsAroundText(&doc)
        #expect(png.after != png.before, "the text layer left the export unchanged")
    }
}
