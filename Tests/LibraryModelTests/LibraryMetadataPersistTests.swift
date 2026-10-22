// LibraryMetadataPersistTests.swift: keywords, title, caption and camera in catalog v1 (metadata-more
// MD-12), each key only when non-empty. Written before its code (rule 13, MD-9); enabled by MD-12.
import CoreColor
import Foundation
@testable import LibraryModel
import Testing

private let coding = LiveCatalogCoding()

private func photoObjects(_ photos: [PhotoItem]) throws -> [[String: Any]] {
    let object = try JSONSerialization.jsonObject(with: try coding.encode(photos))
    return try #require((object as? [String: Any])?["photos"] as? [[String: Any]])
}

@Test func aPhotoWithAllItsMetadataRoundTripsEqual() throws {
    let camera = CameraDetails(
        make: "Fujifilm", model: "X-T5", lens: "23mm", iso: 400, exposureTime: 1.0 / 250, fNumber: 2.8, focalLength: 23)
    let photo = PhotoItem(
        name: "IMG_0010", captureDate: Date(timeIntervalSince1970: 1_780_308_000), color: Color3(0.5, 0.5, 0.5),
        keywords: ["Beach", "Sunset"], title: "Harbour at dawn", caption: "Low tide", camera: camera)
    let data = try coding.encode([photo])
    #expect(try coding.decode(data) == [photo])
    #expect(try coding.encode(try coding.decode(data)) == data)
    let written = try #require(try photoObjects([photo]).first)
    #expect(written["keywords"] as? [String] == ["Beach", "Sunset"])
    #expect(written["title"] as? String == "Harbour at dawn" && written["caption"] as? String == "Low tide")
}

@Test func theGoldenStaysByteEqualAndDecodesEmpty() throws {
    let data = try coding.encode(LibraryPersistGolden.photos)
    #expect(String(decoding: data, as: UTF8.self) == LibraryPersistGolden.catalogV1)
    let decoded = try coding.decode(Data(LibraryPersistGolden.catalogV1.utf8))
    #expect(decoded.allSatisfy { $0.keywords.isEmpty && $0.title.isEmpty && $0.caption.isEmpty && $0.camera == .none })
}

@Test func onlyTheFieldsAPhotoHasAreWritten() throws {
    let photo = PhotoItem(
        name: "IMG_0011", captureDate: Date(timeIntervalSince1970: 0), color: Color3(0, 0, 0),
        camera: CameraDetails(iso: 800))
    let written = try #require(try photoObjects([photo]).first)
    for key in ["keywords", "title", "caption"] { #expect(written[key] == nil, "\(key) written") }
    let camera = try #require(written["camera"] as? [String: Any])
    #expect(Set(camera.keys) == ["iso"] && camera["iso"] as? Int == 800)
    #expect(try coding.decode(try coding.encode([photo])) == [photo])
}
