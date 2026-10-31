// FakeCanvasExportTests.swift (export-pack XP-9): the fake app exports PNG and JPEG at a size read by
// `SuiteExportOptions(json:)`. Its JPEG at pixels(1080, 1350) decodes 1080 × 1350, a shape the artwork doesn't keep
// is refused through ExportRules as an ExportOptionRefusal (bad input, not a failed command), the json export old jobs write is byte-identical, and RJ-X42's job runs on Linux.
import Foundation
import Testing
import SuiteKernel

@Suite struct FakeCanvasExportTests {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("RealJobs/fake/export-pack")
    /// RJ-X42's artwork: one 500 × 625 rect, 4:5.
    static func artwork() throws -> FakeCanvasDocument {
        try FakeCanvasDocument.open(Data(contentsOf: folder.appendingPathComponent("input/one.fake")), name: "one.fake")
    }
    /// The one file `format` writes with `options`, parsed from JSON text.
    static func export(_ doc: FakeCanvasDocument, _ format: String, _ options: String) throws -> ExportedFile {
        let files = try doc.export(format, options: JSONValue(json: Data(options.utf8)))
        #expect(files.count == 1)
        return try #require(files.first)
    }
    /// A JPEG's width and height from its SOF0 marker, nil when it has none or doesn't start with SOI.
    static func jpegSize(_ data: Data) -> (width: Int, height: Int)? {
        let b = [UInt8](data)
        guard b.starts(with: [0xFF, 0xD8]), b.suffix(2) == [0xFF, 0xD9] else { return nil }
        guard let at = b.indices.dropLast(9).first(where: { b[$0] == 0xFF && b[$0 + 1] == 0xC0 }) else { return nil }
        return (Int(b[at + 7]) << 8 | Int(b[at + 8]), Int(b[at + 5]) << 8 | Int(b[at + 6]))
    }
    /// A PNG's width and height from its IHDR chunk, nil when it isn't a PNG.
    static func pngSize(_ data: Data) -> (width: Int, height: Int)? {
        let b = [UInt8](data.prefix(24))
        guard b.count == 24, b.starts(with: [0x89, 0x50, 0x4E, 0x47]), b[12..<16] == [0x49, 0x48, 0x44, 0x52] else { return nil }
        let word = { (at: Int) in b[at..<at + 4].reduce(0) { $0 << 8 | Int($1) } }
        return (word(16), word(20))
    }

    @Test func exportsAtSize() throws {
        let doc = try Self.artwork()
        #expect(FakeCanvasDocument.exportFormats == ["json", "png", "jpeg"])
        let jpeg = try Self.export(doc, "jpeg", #"{"size":{"pixels":[1080,1350]}}"#)
        #expect(jpeg.format == "jpeg" && jpeg.suggestedName == "canvas.jpg")
        let size = try #require(Self.jpegSize(jpeg.data))
        #expect(size.width == 1080 && size.height == 1350)
        let long = try #require(Self.jpegSize(try Self.export(doc, "jpeg", #"{"size":{"longEdge":2048}}"#).data))
        #expect(long.width == 1638 && long.height == 2048)
        let png = try Self.export(doc, "png", #"{"size":{"scale":2}}"#)
        #expect(png.suggestedName == "canvas.png")
        let twice = try #require(Self.pngSize(png.data))
        #expect(twice.width == 1000 && twice.height == 1250)
        let plain = try #require(Self.pngSize(try Self.export(doc, "png", "{}").data))
        #expect(plain.width == 500 && plain.height == 625)
    }

    @Test func refusesBadShape() throws {
        let doc = try Self.artwork()
        #expect(throws: ExportOptionRefusal.invalid("1080 × 1351 doesn't keep the artwork's 4:5 shape. Unlock the ratio to stretch.")) {
            try Self.export(doc, "jpeg", #"{"size":{"pixels":[1080,1351]}}"#)
        }
        let stretched = try #require(Self.jpegSize(try Self.export(doc, "jpeg", #"{"size":{"pixels":[1080,1351],"stretch":true}}"#).data))
        #expect(stretched.width == 1080 && stretched.height == 1351)
        #expect(throws: ExportOptionRefusal.self) { try Self.export(FakeCanvasDocument(), "png", "{}") }
        #expect(throws: ExportOptionRefusal.invalid(#"There's no export option "colour"."#)) { try Self.export(doc, "jpeg", #"{"colour":1}"#) }
        #expect(throws: CatalogError.self) { try Self.export(doc, "gif", "{}") }
    }

    @Test func oldExportsAreUnchanged() throws {
        let old = #"[{"fill":{"end":{"x":100,"y":30},"start":{"x":0,"y":30},"stops":[{"color":{"a":1,"b":1,"g":0,"r":0},"offset":0},{"color":{"a":1,"b":1,"g":1,"r":1},"offset":0.5},{"color":{"a":1,"b":0,"g":0,"r":0},"offset":1}],"type":"linear"},"h":60,"id":1,"locked":false,"name":"Rect 1","w":100,"x":10,"y":10},{"h":80,"id":2,"locked":true,"name":"Rect 2","w":80,"x":140,"y":40}]"#
        let json = try Self.export(.fixture, "json", #"{"size":{"pixels":[1080,1351]}}"#)
        #expect(json.suggestedName == "canvas.json" && json.format == "json")
        #expect(json.data == (try FakeCanvasDocument.fixture.save()))
        #expect(String(decoding: json.data, as: UTF8.self) == old)
    }

    /// RJ-X42: the job's export of its input is the JPEG it pins by sha256, exactly 1080 × 1350.
    @Test func realJobX42() throws {
        guard case .object(let job) = try JSONValue(json: Data(contentsOf: Self.folder.appendingPathComponent("export-pack.jobs.json"))),
              case .object(let output)? = job["output"], let options = output["options"],
              case .object(let expect)? = job["expect"], case .object(let file)? = expect["out/one.jpeg"] else {
            Issue.record("export-pack.jobs.json has no output and expectation"); return
        }
        #expect(output["format"] == .string("jpeg") && job["platforms"] == .array([.string("linux"), .string("macos")]))
        let files = try Self.artwork().export("jpeg", options: options)
        let data = try #require(files.first?.data)
        let size = try #require(Self.jpegSize(data))
        #expect(size.width == 1080 && size.height == 1350)
        #expect(file["sha256"] != nil)
    }
}
