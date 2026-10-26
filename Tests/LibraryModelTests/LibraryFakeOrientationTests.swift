// LibraryFakeOrientationTests.swift (orientation-crop OC-9): the fakes stand a turned photo as it
// faces, so a journey on the fixture sees Rotate Right stand a landscape thumbnail and loupe up,
// and a crop on top still takes its share of the turned sides; the aspect picker's commands on a
// draft only move the draft. Runs on Linux and macOS.
import CoreColor
import Foundation
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryFakeOrientationTests {
    private let wide = PhotoItem(id: "scan", name: "scan", captureDate: Date(timeIntervalSince1970: 0),
                                 color: Color3(0.5, 0.5, 0.5), pixelSize: PixelSize(width: 300, height: 200))

    @Test func rotateRightStandsTheFakeThumbnailAndLoupeUp() async throws {
        var catalog = LibraryCatalog(services: .fake())
        catalog.load([wide])
        catalog.select(["scan"])
        _ = try LibraryCatalog.catalog.run("image.rotate-cw", params: .object([:]), on: &catalog)
        let turned = try #require(catalog.items.first)
        #expect(turned.develop.orientation == .right)
        let thumbnail = try await FakeThumbnails().thumbnail(for: turned, longSide: 300)
        #expect(thumbnail.size == PixelSize(width: 200, height: 300))
        let loupe = try await FakeLoupe().render(turned, settings: turned.develop, longSide: 300, quality: .full)
        #expect(loupe.image.size == PixelSize(width: 200, height: 300))
    }

    /// The aspect picker's 4:5 portrait on an open draft frames a tall 4:5 and records no step of its own,
    /// so Undo after Apply still reads "Undo Crop".
    @Test func portraitOnADraftFramesTallWithNoStep() throws {
        var catalog = LibraryCatalog(services: .fake())
        catalog.load([wide])
        catalog.open("scan")
        catalog.beginCrop()
        let params: JSONValue = .object(["aspect": .string("4:5"), "orientation": .string("portrait")])
        let outcome = try LibraryCatalog.catalog.run("crop.set-aspect", params: params, on: &catalog)
        #expect(outcome.undoStep == nil)
        let frame = try #require(catalog.cropFrame)
        #expect(frame.width * 5 == frame.height * 4, "4:5 portrait framed \(frame)")
        _ = try LibraryCatalog.catalog.run("crop.swap", params: .object([:]), on: &catalog)
        let swapped = try #require(catalog.cropFrame)
        #expect(swapped.width * 4 == swapped.height * 5, "the swap framed \(swapped)")
    }

    @Test func aCropTakesItsShareOfTheTurnedSides() {
        let half = CropSettings(angle: 0, rect: UnitRect(x: 0, y: 0, width: 0.5, height: 1), aspect: CropAspect.free)
        #expect(FakeBehavior.cropShaped(wide, half, facing: .right).pixelSize == PixelSize(width: 100, height: 300))
        #expect(FakeBehavior.cropShaped(wide, nil, facing: .down).pixelSize == wide.pixelSize)
        #expect(FakeBehavior.cropShaped(wide, half).pixelSize == PixelSize(width: 150, height: 200))
    }

    /// X belongs to the aspect picker's swap while a crop draft is open, so it never rejects the
    /// photo there; once the crop closes, X rejects again. P still picks with the draft open.
    @Test func xNeverRejectsWhileACropDraftIsOpen() throws {
        var catalog = LibraryCatalog(services: .fake())
        catalog.load([wide])
        catalog.open("scan")
        catalog.beginCrop()
        #expect(catalog.cullChange(forKey: .reject) == nil)
        if let change = catalog.cullChange(forKey: .reject) { try catalog.run(.cull(change)) }
        #expect(catalog.items.first?.flag == PhotoFlag.none)
        #expect(catalog.cullChange(forKey: .pick) == .flag(.pick))
        catalog.cancelCrop()
        #expect(catalog.cullChange(forKey: .reject) == .flag(.reject))
    }
}
