// LibraryCatalogCodingTests.swift: the catalog v1 file (persist PE-2,
// QB-LIB-V7): byte-stable round trips, the golden, and the files that must
// not decode. Runs on Linux and macOS.
import CoreColor
import Foundation
@testable import LibraryModel
import Testing

private let coding = LiveCatalogCoding()

private func text(_ data: Data) -> String { String(decoding: data, as: UTF8.self) }

@Test func shootWithDevelopAndCropRoundTripsByteEqual() throws {
    var shoot = LibraryFixtures.photos(named: "shoot")
    let crop = CropSettings(angle: -3, rect: UnitRect(x: 0.125, y: 0.0625, width: 0.75, height: 0.875), aspect: .free)
    shoot[1].develop = DevelopSettings.neutral.setting(.temperature, to: 12).setting(.shadows, to: 40).setting(crop: crop)
    let first = try coding.encode(shoot)
    let decoded = try coding.decode(first)
    #expect(decoded == shoot)
    #expect(try coding.encode(decoded) == first)
    #expect(try coding.encode(shoot) == first)
}

@Test func theFixedCatalogEncodesToTheGolden() throws {
    let data = try coding.encode(LibraryPersistGolden.photos)
    #expect(text(data) == LibraryPersistGolden.catalogV1)
    #expect(text(data).hasSuffix("}\n"))
    #expect(!text(data).contains(#"\/"#))
    #expect(try coding.decode(Data(LibraryPersistGolden.catalogV1.utf8)) == LibraryPersistGolden.photos)
}

@Test func theGoldenWithoutDevelopDecodesNeutral() throws {
    let object = try JSONSerialization.jsonObject(with: Data(LibraryPersistGolden.catalogV1.utf8))
    var top = try #require(object as? [String: Any])
    let photos = try #require(top["photos"] as? [[String: Any]])
    #expect(photos.contains { $0["develop"] != nil })
    top["photos"] = photos.map { photo in photo.filter { $0.key != "develop" } }
    let decoded = try coding.decode(try JSONSerialization.data(withJSONObject: top))
    #expect(decoded.count == 3)
    #expect(decoded.allSatisfy { $0.develop == .neutral })
    #expect(decoded.map(\.id) == LibraryPersistGolden.photos.map(\.id))
    #expect(decoded.first?.rating == 3 && decoded.first?.label == .red && decoded.first?.flag == .pick)
}

@Test(arguments: ["not json", "[]", "{}", #"{"version": 1}"#, #"{"version": 0, "photos": []}"#])
func aFileThatIsNotACatalogIsDamaged(_ file: String) {
    #expect(throws: LibraryError.damagedCatalog("")) { try coding.decode(Data(file.utf8)) }
}

@Test func aNewerVersionIsRefusedByNumber() {
    #expect(throws: LibraryError.newerCatalog(version: 2)) { try coding.decode(Data(#"{"version": 2}"#.utf8)) }
}

@Test func anUnknownFlagIsDamaged() throws {
    let bad = LibraryPersistGolden.catalogV1.replacingOccurrences(of: #""Reject""#, with: #""Maybe""#)
    #expect(throws: LibraryError.damagedCatalog("")) { try coding.decode(Data(bad.utf8)) }
}

@Test func anEmptyCatalogRoundTrips() throws {
    let data = try coding.encode([])
    #expect(try coding.decode(data).isEmpty)
}

@Test func liveCodingIsAvailable() {
    #expect(LiveCatalogCoding.unavailable == nil)
}