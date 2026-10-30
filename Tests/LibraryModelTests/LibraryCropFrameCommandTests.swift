// LibraryCropFrameCommandTests.swift: crop.set-frame takes the straightened
// photo's pixels and says so (#5954). On the live crop with `IMG_0001`
// (6000 × 4000): the schema names pixels and a 16 px floor, the example is
// not a 1 px crop, a unit-square guess (x 0.5, w 0.4) is refused and leaves
// the photo as it was, and a pixel frame at 10° is stored as asked, in the
// window's catalog and in the CLI's headless one (whose export cuts with the
// live crop). Runs on Linux and macOS.
import Foundation
@testable import LibraryModel
import CoreColor
import SuiteKernel
import Testing

@Suite
struct LibraryCropFrameCommandTests {
    private let catalog = LibraryCatalog.catalog

    private static func text(_ value: JSONValue?) -> String {
        if case .string(let s)? = value { return s }
        return ""
    }

    @Test func theSchemaSaysPixelsAndTheExampleIsAPhotoSizedFrame() throws {
        let spec = try #require(catalog.spec("crop.set-frame"))
        guard case .object(let schema) = spec.params.json, case .object(let props)? = schema["properties"],
              case .object(let w)? = props["w"], case .object(let x)? = props["x"] else {
            Issue.record("crop.set-frame has no x and w properties")
            return
        }
        #expect(Self.text(x["description"]).contains("pixels"))
        #expect(Self.text(w["description"]).contains("pixels"))
        #expect(w["minimum"] == .number(16))
        guard case .object(let example) = spec.example, case .number(let ew)? = example["w"],
              case .number(let eh)? = example["h"] else {
            Issue.record("crop.set-frame's example has no w and h")
            return
        }
        #expect(ew >= 16 && eh >= 16)
    }

    @Test func aUnitSquareGuessIsRefusedAndStoresNothing() throws {
        var library = cropLiveLoupe()
        let before = library.items
        let guess = JSONValue.object(["x": .number(0.5), "y": .number(0), "w": .number(0.4), "h": .number(1), "angle": .number(0)])
        #expect(throws: (any Error).self) { try catalog.run("crop.set-frame", params: guess, on: &library) }
        #expect(library.items == before)
    }

    @Test func aFrameUnderSixteenPixelsIsRefusedInPlainWords() throws {
        var doc = LibraryCropDocument(library: cropLiveLoupe())
        let tiny = CropFrame(rect: Rect(minX: 10, minY: 10, maxX: 14, maxY: 2010), angle: 0)
        do {
            try doc.setCropFrame(tiny, name: "Crop Frame")
            Issue.record("a 4 px wide frame was stored")
        } catch {
            #expect("\(error)".contains("pixels"))
        }
        #expect(doc.library.loupeItem?.develop.crop == nil)
    }

    @Test func aPixelFrameAtTenDegreesIsStoredAsAsked() throws {
        var library = cropLiveLoupe()
        let frame = JSONValue.object(["x": .number(600), "y": .number(400), "w": .number(2400), "h": .number(2000),
                                      "angle": .number(10)])
        _ = try catalog.run("crop.set-frame", params: frame, on: &library)
        let photo = try #require(library.loupeItem)
        let stored = try #require(photo.develop.crop)
        #expect(stored.angle == 10)
        let size = library.croppedSize(photo)
        #expect(abs(size.width - 2400) <= 1 && abs(size.height - 2000) <= 1)
    }

    /// The CLI and MCP drive `LibraryHeadless`; its export cuts with `LiveCrop`, so set-frame must read
    /// pixels the same way, or 2400 × 2000 at 10° of 6000 × 4000 exports 1925 × 1604 (#5954).
    @Test func theHeadlessCatalogStoresAPixelFrameAtTenDegreesAsAsked() throws {
        let photo = PhotoItem(id: "big", name: "big", captureDate: Date(timeIntervalSince1970: 0), color: Color3(0.5, 0.5, 0.5),
                              pixelSize: PixelSize(width: 6000, height: 4000))
        var doc = LibraryHeadless(photos: [photo], images: [:], stem: "shoot")
        _ = try LibraryHeadless.catalog.run("edit.select", params: .object(["ids": .array([.string("big")])]), on: &doc)
        _ = try LibraryHeadless.catalog.run("view.loupe", params: .object([:]), on: &doc)
        let frame = JSONValue.object(["x": .number(600), "y": .number(400), "w": .number(2400), "h": .number(2000),
                                      "angle": .number(10)])
        _ = try LibraryHeadless.catalog.run("crop.set-frame", params: frame, on: &doc)
        let stored = try #require(doc.library.items.first)
        let size = LiveExporter.croppedSize(stored)
        #expect(abs(size.width - 2400) <= 1 && abs(size.height - 2000) <= 1)
    }
}
