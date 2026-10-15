// LibraryContractsTests.swift: the values the use-case contracts take
// (undo names, export clamps) and the sample picture every service draws.
import CoreColor
import Foundation
import Testing

@testable import LibraryModel

@Test func cullChangesNameTheirUndoSteps() {
    #expect(CullChange.flag(.reject).undoName == "Reject")
    #expect(CullChange.flag(.pick).undoName == "Pick")
    #expect(CullChange.flag(.none).undoName == "Clear Flag")
    #expect(CullChange.rating(3).undoName == "Set Rating")
    #expect(CullChange.label(.red).undoName == "Set Label")
    #expect(CullChange.label(nil).undoName == "Set Label")
}

@Test func exportOptionsClampToTheirRanges() {
    let high = ExportOptions(longEdge: 99999, quality: 120, folder: "/out")
    #expect(high.longEdge == 16384)
    #expect(high.quality == 100)
    let low = ExportOptions(longEdge: 1, quality: -5, folder: "/out")
    #expect(low.longEdge == 16)
    #expect(low.quality == 0)
    let original = ExportOptions(longEdge: nil, folder: "/out")
    #expect(original.longEdge == nil)
    #expect(original.quality == 85)
    #expect(ExportOptions(folder: "/out").longEdge == ExportOptions.defaultLongEdge)
}

@Test func sampleImageIsAGradientToHalfTheColor() throws {
    let photo = PhotoItem(name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 0), color: Color3(0.8, 0.4, 0.2))
    let image = try #require(SampleImage.image(for: photo, longSide: 64))
    #expect(image.size == PixelSize(width: 64, height: 48))
    #expect(Array(image.rgba8.prefix(4)) == photo.pixel)
    let last = Array(image.rgba8.suffix(4))
    for channel in 0..<3 {
        let half = Double(photo.pixel[channel]) / 2
        #expect(abs(Double(last[channel]) - half) <= 1)
    }
    #expect(last[3] == 255)
}

@Test func sampleImageWithoutALongSideIsFullSize() throws {
    let photo = PhotoItem(name: "a", captureDate: Date(timeIntervalSince1970: 0), color: Color3(1, 0, 0),
                          pixelSize: PixelSize(width: 1, height: 3))
    let image = try #require(SampleImage.image(for: photo, longSide: nil))
    #expect(image.size == PixelSize(width: 1, height: 3))
    #expect(image.rgba8 == [255, 0, 0, 255, 255, 0, 0, 255, 255, 0, 0, 255])
}
