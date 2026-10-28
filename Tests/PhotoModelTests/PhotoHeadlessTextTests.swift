// PhotoHeadlessTextTests.swift (#5193): PhotoHeadless made or opened on the caller's services draws its text layers
// with that text service, so a host holding the live text (the CLI, once it can reach it) passes it in and a
// `text.add` then export has the words in it.
import CoreRaster
import Foundation
@testable import PhotoModel
import SuiteKernel
import SuiteModel
import Testing

/// FakeText's metrics and fonts, drawing every frame opaque red so the export shows where the text went.
private struct RedText: TextServices {
    let fake = FakeText()
    func measure(_ spans: [TextSpan]) throws(SuiteError) -> [SpanMetrics] { try fake.measure(spans) }
    func families() -> [FontFamily] { fake.families() }
    func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame {
        _ = try fake.draw(spans, width: width, height: height)
        let red: [UInt8] = [255, 0, 0, 255]
        return try MediaFrame(width: width, height: height, rgba: Array((0..<(width * height)).map { _ in red }.joined()))
    }
}

/// `.live` with `RedText` for text.
private var redServices: PhotoServices {
    var services = PhotoServices.live
    services.text = RedText()
    return services
}

/// Runs `text.add` with "SALE" at (40, 60) on `doc`, exports PNG and returns the decoded pixel at (42, 62).
private func saleExportPixel(_ doc: inout PhotoHeadless) throws -> [UInt8] {
    let params = JSONValue.object(["x": .number(40), "y": .number(60), "words": .string("SALE")])
    _ = try PhotoHeadless.catalog.run("text.add", params: params, on: &doc)
    let file = try #require(doc.export("png", options: .object([:])).first)
    let image = try PhotoHeadless.codec.decode(file.data, longestSide: nil)
    let at = (62 * image.width + 42) * 4
    return Array(image.rgba8[at..<at + 4])
}

@Suite struct PhotoHeadlessTextTests {
    @Test func aNewDocumentDrawsTextWithTheCallersTextService() throws {
        var doc = try PhotoHeadless.new(.object(["width": .number(200), "height": .number(150)]), services: redServices)
        #expect(doc.workspace.services.text is RedText)
        #expect(try saleExportPixel(&doc) == [255, 0, 0, 255])
    }

    @Test func anOpenedImageDrawsTextWithTheCallersTextService() throws {
        let white = [UInt8](repeating: 255, count: 200 * 150 * 4)
        let png = try PhotoHeadless.codec.encode(DecodedImage(rgba8: white, width: 200, height: 150), as: .png, quality: 1)
        var doc = try PhotoHeadless.open(png, name: "white.png", services: redServices)
        #expect(doc.workspace.services.text is RedText)
        #expect(try saleExportPixel(&doc) == [255, 0, 0, 255])
    }
}
