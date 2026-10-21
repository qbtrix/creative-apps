// LibraryPhotoDetailsTests.swift: the photo details contract (metadata-more
// MD-1). Camera details clean what a file says, every photo carries keywords,
// a title, a caption and camera details through its copies, an import
// candidate made the old way has none, and the inspector reads the selected
// photos in the sort. Runs on Linux and macOS.
import CoreColor
import Foundation
@testable import LibraryModel
import Testing

private let epoch = Date(timeIntervalSince1970: 0)

@Test func cameraDetailsKeepOnlyCleanText() {
    let details = CameraDetails(make: " Maker\0 ", model: "", iso: 0, exposureTime: .nan, fNumber: -2, focalLength: 35)
    #expect(details == CameraDetails(make: "Maker", focalLength: 35))
    #expect(details.make == "Maker")
    #expect(details.model == nil && details.lens == nil && details.iso == nil)
    #expect(details.exposureTime == nil && details.fNumber == nil)
    #expect(details.focalLength == 35)
    #expect(!details.isEmpty)
    #expect(CameraDetails(lens: "\0\0 \t").lens == nil)
}

@Test func cameraDetailsDropZeroAndInfiniteNumbers() {
    #expect(CameraDetails(iso: 0, exposureTime: 0, fNumber: 0, focalLength: 0).isEmpty)
    #expect(CameraDetails(exposureTime: .infinity, fNumber: -.infinity).isEmpty)
    #expect(CameraDetails(iso: -100).isEmpty)
    let kept = CameraDetails(iso: 400, exposureTime: 0.004, fNumber: 2.8)
    #expect(kept.iso == 400 && kept.exposureTime == 0.004 && kept.fNumber == 2.8)
}

@Test func noCameraDetailsAreEmpty() {
    #expect(CameraDetails.none.isEmpty)
    #expect(CameraDetails() == .none)
    #expect(!CameraDetails(model: "FX-1").isEmpty)
}

@Test func aPhotoKeepsItsDetailsThroughEveryCopy() {
    let camera = CameraDetails(make: "Fixture Optics", model: "FX-1", lens: "50mm F1.8", iso: 400)
    let photo = PhotoItem(
        name: "IMG_0001", captureDate: epoch, color: Color3(0.2, 0.4, 0.6),
        keywords: ["Beach", "Sunset"], title: "Harbour", caption: "Low tide", camera: camera)
    for copy in [photo.withID("IMG_0001 2"), photo.withSize(PixelSize(width: 10, height: 20))] {
        #expect(copy.keywords == ["Beach", "Sunset"])
        #expect(copy.title == "Harbour")
        #expect(copy.caption == "Low tide")
        #expect(copy.camera == camera)
    }
}

@Test func anExistingPhotoCallHasNoDetails() {
    let photo = PhotoItem(name: "IMG_0001", captureDate: epoch, color: Color3(0.2, 0.4, 0.6))
    #expect(photo.keywords.isEmpty && photo.title.isEmpty && photo.caption.isEmpty)
    #expect(photo.camera == .none)
}

@Test func theOldImportCandidateInitHasNoCamera() {
    let candidate = ImportCandidate(
        path: "/a/IMG_1.jpg", captureDate: epoch, pixelSize: PixelSize(width: 4, height: 3), kind: .jpeg)
    #expect(candidate.camera == .none)
    let withCamera = ImportCandidate(
        path: "/a/IMG_1.jpg", captureDate: epoch, pixelSize: PixelSize(width: 4, height: 3), kind: .jpeg,
        camera: CameraDetails(iso: 800))
    #expect(withCamera.camera.iso == 800)
}

@Test func aSavedCatalogWithoutTheNewKeysDecodesWithNoDetails() throws {
    let photos = try LiveCatalogCoding().decode(Data(LibraryPersistGolden.catalogV1.utf8))
    #expect(!photos.isEmpty)
    for photo in photos {
        #expect(photo.keywords.isEmpty && photo.title.isEmpty && photo.caption.isEmpty)
        #expect(photo.camera.isEmpty)
    }
}

@Test func selectedPhotosFollowTheSort() {
    var library = LibraryCatalog()
    library.load([
        PhotoItem(name: "C", captureDate: Date(timeIntervalSince1970: 10), color: Color3(0, 0, 0), rating: 1),
        PhotoItem(name: "A", captureDate: Date(timeIntervalSince1970: 30), color: Color3(0, 0, 0), rating: 5),
        PhotoItem(name: "B", captureDate: Date(timeIntervalSince1970: 20), color: Color3(0, 0, 0), rating: 3),
    ])
    #expect(library.selectedPhotos.isEmpty)
    library.select(["A", "C"])
    #expect(library.selectedPhotos.map(\.id) == ["C", "A"])
    library.setSort(.name)
    #expect(library.selectedPhotos.map(\.id) == ["A", "C"])
    library.setSort(.rating)
    #expect(library.selectedPhotos.map(\.id) == ["A", "C"])
    #expect(library.selectedCameraRows.isEmpty)
}

@Test func cameraFieldsRunInInfoTabOrder() {
    #expect(CameraField.allCases.map(\.rawValue)
        == ["Camera", "Lens", "Aperture", "Shutter", "ISO", "Focal Length", "Taken"])
    #expect(MetadataInspectorID.camera(.lens) == "library.metadata.camera.lens")
    #expect(Set(CameraField.allCases.map(MetadataInspectorID.camera)).count == CameraField.allCases.count)
}
