// LibraryCameraRowsTests.swift: the Info tab's camera details (metadata-more
// MD-b, check row MD-6): `CameraDetails(exif:tiff:)`, the display texts and
// `CameraRow.rows(for:)`. Written before its code (lead.md, contract rule 13,
// MD-5); MD-6 turned them on. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

private let cameras = LibraryFixtures.photos(named: "cameras")

private func photos(_ numbers: ClosedRange<Int>) -> [PhotoItem] {
    numbers.compactMap { n in cameras.first { $0.name == "IMG_" + LibraryFixtures.padded(n, to: 4) } }
}

/// The text of the row for `field`, nil when there is no such row or it holds dates.
private func text(_ field: CameraField, _ rows: [CameraRow]) -> String? {
    guard case .text(let value)? = rows.first(where: { $0.field == field })?.value else { return nil }
    return value
}

@Test func exifAndTIFFTagsAreRead() {
    let exif: [String: Any] = [
        "LensModel": "35mm F1.4", "ISOSpeedRatings": [800], "ExposureTime": 0.004, "FNumber": 2.0, "FocalLength": 35.0,
    ]
    let details = CameraDetails(exif: exif, tiff: ["Make": "Test Maker", "Model": "TM-10"])
    #expect(details == CameraDetails(
        make: "Test Maker", model: "TM-10", lens: "35mm F1.4", iso: 800, exposureTime: 0.004, fNumber: 2, focalLength: 35))
    #expect(!details.isEmpty)
}

@Test func isoIsAnArrayOrOneNumber() {
    #expect(CameraDetails(exif: ["ISOSpeedRatings": [400, 800]], tiff: [:]).iso == 400)
    #expect(CameraDetails(exif: ["ISOSpeedRatings": 1600], tiff: [:]).iso == 1600)
    #expect(CameraDetails(exif: ["ISOSpeedRatings": [Int]()], tiff: [:]).iso == nil)
}

@Test func valuesThatAreNotNumbersAreIgnored() {
    let exif: [String: Any] = ["ISOSpeedRatings": "fast", "ExposureTime": "1/250", "FNumber": "2.8", "FocalLength": [35]]
    let details = CameraDetails(exif: exif, tiff: ["Make": 7, "Model": "  "])
    #expect(details == CameraDetails.none && details.isEmpty)
    #expect(CameraDetails(exif: [:], tiff: [:]) == CameraDetails.none)
}

@Test func displayTexts() {
    let shutters = [0.004, 1.0 / 3, 0.3, 2.5].map { CameraDetails(exposureTime: $0).shutterText }
    #expect(shutters == ["1/250 s", "1/3 s", "0.3 s", "2.5 s"])
    #expect([2.0, 2.8].map { CameraDetails(fNumber: $0).apertureText } == ["f/2", "f/2.8"])
    #expect(CameraDetails(focalLength: 35).focalText == "35 mm")
    #expect(CameraDetails(iso: 400).isoText == "ISO 400")
    let none = CameraDetails.none
    #expect([none.shutterText, none.apertureText, none.focalText, none.isoText, none.cameraText] == [nil, nil, nil, nil, nil])
}

@Test func cameraTextLeavesARepeatedMakeOff() {
    #expect(CameraDetails(make: "Fixture Optics", model: "FX-1").cameraText == "Fixture Optics FX-1")
    #expect(CameraDetails(make: "Fixture Optics", model: "Fixture Optics FX-1").cameraText == "Fixture Optics FX-1")
    #expect(CameraDetails(make: "FIXTURE OPTICS", model: "fixture optics FX-1").cameraText == "fixture optics FX-1")
    #expect(CameraDetails(make: "Fixture Optics").cameraText == "Fixture Optics")
    #expect(CameraDetails(model: "FX-2").cameraText == "FX-2")
}

@Test func onePhotosRowsInFieldOrderWithSearches() throws {
    let photo = try #require(photos(1...1).first)
    let rows = CameraRow.rows(for: [photo])
    #expect(rows.map(\.field) == CameraField.allCases)
    let texts = CameraField.allCases.dropLast().map { text($0, rows) }
    #expect(texts == ["Fixture Optics FX-1", "24-70mm F2.8", "f/2.8", "1/2000 s", "ISO 100", "24 mm"])
    #expect(rows.last?.value == .dates(photo.captureDate, photo.captureDate))
    #expect(rows.first { $0.field == .camera }?.search == "camera:\"Fixture Optics FX-1\"")
    #expect(rows.first { $0.field == .lens }?.search == "lens:\"24-70mm F2.8\"")
    #expect(rows.filter { $0.field != .camera && $0.field != .lens }.allSatisfy { $0.search == nil })
}

@Test func severalPhotosShowCountsAndRanges() {
    let six = photos(1...6)
    let rows = CameraRow.rows(for: six)
    #expect(six.count == 6)
    #expect(rows.map(\.field) == CameraField.allCases)
    let texts = CameraField.allCases.dropLast().map { text($0, rows) }
    #expect(texts == ["2 cameras", "3 lenses", "f/1.8–f/8", "1/2000–1/30 s", "ISO 100–3200", "24–100 mm"])
    #expect(rows.allSatisfy { $0.search == nil })
    let dates = six.map(\.captureDate).sorted()
    #expect(rows.last?.value == dates.first.flatMap { first in dates.last.map { CameraRowValue.dates(first, $0) } })
}

@Test func aSharedValueAcrossPhotosIsOneTextWithItsSearch() {
    let pair = photos(1...4).enumerated().filter { $0.offset % 3 == 0 }.map(\.element)
    let rows = CameraRow.rows(for: pair)
    #expect(text(.lens, rows) == "24-70mm F2.8" && text(.aperture, rows) == "f/2.8")
    #expect(rows.first { $0.field == .lens }?.search == "lens:\"24-70mm F2.8\"")
    #expect(text(.iso, rows) == "ISO 100–800")
}

@Test func aFieldNoPhotoHasHasNoRow() {
    let date = Date(timeIntervalSince1970: 1_780_308_000)
    let bare = PhotoItem(
        name: "a", captureDate: date, color: Color3(0.5, 0.5, 0.5),
        camera: CameraDetails(make: "Test Maker", model: "TM-10"))
    let rows = CameraRow.rows(for: [bare])
    #expect(rows.map(\.field) == [.camera, .taken])
    #expect(text(.camera, rows) == "Test Maker TM-10")
    #expect(rows.last?.value == .dates(date, date))
    #expect(CameraRow.rows(for: []).isEmpty)
}

@Test func theSelectionsRowsAreItsPhotosRows() {
    var catalog = LibraryCatalog()
    catalog.load(cameras)
    catalog.setSort(.name)
    catalog.select(Set(photos(1...6).map(\.id)))
    #expect(catalog.selectedCameraRows == CameraRow.rows(for: photos(1...6)))
    #expect(MetadataInspectorID.camera(.focalLength) == "library.metadata.camera.focalLength")
}
