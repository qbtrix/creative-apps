// LibraryOrientationTests.swift (orientation-crop OC-7, turned on by OC-8): a photo's orientation lives in its develop
// settings. Rotate and flip compose and survive the catalog file; an old catalog decodes up and re-encodes byte for
// byte; the render turns the photo before its crop, so a turned landscape exports portrait. Every edit runs through
// Library's command catalog by id, and the stored orientation is read from the catalog file (EXIF 1...8, absent
// when up). Runs on Linux and macOS.
import CoreColor
import CoreRaster
import Foundation
@testable import LibraryModel
import SuiteKernel
import Testing

/// One 600 x 400 photo open in the loupe on the fakes.
private func landscape() -> LibraryCatalog {
    var catalog = LibraryCatalog(services: .fake())
    catalog.load([PhotoItem(id: "scan", name: "scan", captureDate: Date(timeIntervalSince1970: 0),
                            color: Color3(0.5, 0.5, 0.5), pixelSize: PixelSize(width: 600, height: 400))])
    catalog.open("scan")
    return catalog
}

private func run(_ id: String, _ params: JSONValue = .object([:]), on catalog: inout LibraryCatalog) throws -> String? {
    try LibraryCatalog.catalog.run(id, params: params, on: &catalog).undoStep
}

/// The photo's stored orientation as the catalog file writes it, 1 (up) when the file has none.
private func storedOrientation(_ catalog: LibraryCatalog, _ id: String = "scan") throws -> Int {
    let file = try JSONSerialization.jsonObject(with: try LiveCatalogCoding().encode(catalog.items))
    let photos = try #require((file as? [String: Any])?["photos"] as? [[String: Any]])
    let photo = try #require(photos.first { $0["id"] as? String == id })
    return (photo["develop"] as? [String: Any])?["orientation"] as? Int ?? 1
}

private func photo(_ catalog: LibraryCatalog, _ id: String = "scan") throws -> PhotoItem {
    try #require(catalog.items.first { $0.id == id })
}

@Suite struct LibraryOrientationTests {
    @Test func rotateAndFlipComposeAsOneStepEach() throws {
        var catalog = landscape()
        #expect(try run("image.rotate-cw", on: &catalog) == "Rotate Right")
        #expect(try storedOrientation(catalog) == 6)
        #expect(try run("image.rotate-cw", on: &catalog) == "Rotate Right")
        #expect(try storedOrientation(catalog) == 3)
        #expect(try run("image.flip", .object(["axis": .string("horizontal")]), on: &catalog) == "Flip Horizontal")
        #expect(try storedOrientation(catalog) == 4)
        #expect(try run("image.rotate-ccw", on: &catalog) == "Rotate Left")
        #expect(try storedOrientation(catalog) == 7)
        catalog.undo()
        #expect(try storedOrientation(catalog) == 4)
    }

    @Test func aTurnedPhotoSurvivesTheCatalogFile() throws {
        var catalog = landscape()
        _ = try run("image.rotate-180", on: &catalog)
        _ = try run("image.flip", .object(["axis": .string("vertical")]), on: &catalog)
        #expect(try storedOrientation(catalog) == 2)
        let coding = LiveCatalogCoding()
        let file = try coding.encode(catalog.items)
        let decoded = try coding.decode(file)
        #expect(decoded == catalog.items)
        #expect(try coding.encode(decoded) == file)
    }

    @Test func anOldCatalogDecodesUpAndReencodesByteForByte() throws {
        let coding = LiveCatalogCoding()
        let golden = Data(LibraryPersistGolden.catalogV1.utf8)
        let photos = try coding.decode(golden)
        #expect(try coding.encode(photos) == golden)
        #expect(!LibraryPersistGolden.catalogV1.contains("orientation"))
        var catalog = LibraryCatalog(services: .fake())
        catalog.load(photos)
        let id = try #require(photos.first?.id)
        catalog.open(id)
        _ = try run("image.rotate-cw", on: &catalog)
        #expect(try storedOrientation(catalog, id) == 6)
        _ = try run("image.rotate-ccw", on: &catalog)
        #expect(try coding.encode(catalog.items) == golden, "a photo turned back up writes no orientation")
    }

    @Test func aTurnedLandscapeExportsPortrait() throws {
        var catalog = landscape()
        _ = try run("image.rotate-cw", on: &catalog)
        let turned = try photo(catalog)
        #expect(LiveExporter.croppedSize(turned) == PixelSize(width: 400, height: 600))
        let source = try developGradient(width: 600, height: 400)
        let out = try LiveDevelop().render(source, settings: turned.develop)
        #expect(out.width == 400 && out.height == 600)
        for x in [0, 199, 399] { #expect(try out.pixel(x: x, y: 0) == source.pixel(x: 0, y: 399 - x)) }
    }

    @Test func fourFivePortraitCropsTheTurnedPhoto() throws {
        var catalog = landscape()
        _ = try run("image.rotate-cw", on: &catalog)
        let params: JSONValue = .object(["aspect": .string("4:5"), "orientation": .string("portrait")])
        #expect(try run("crop.set-aspect", params, on: &catalog) == "Crop Ratio")
        let cropped = try photo(catalog)
        #expect(LiveExporter.croppedSize(cropped) == PixelSize(width: 400, height: 500))
        let source = try developGradient(width: 600, height: 400)
        let out = try LiveDevelop().render(source, settings: cropped.develop)
        #expect(out.width == 400 && out.height == 500)
        for x in [0, 199, 399] { #expect(try out.pixel(x: x, y: 0) == source.pixel(x: 50, y: 399 - x)) }
    }
}
