// LibraryCropLevelTests.swift: crop CR-9, CR-e's check written first. Auto
// on the live services: the catalog's `leveler` from `LibraryServices.live`
// levels a tilted two-tone horizon, finds none in a flat buffer, and MJ6A
// (`walkAutoStraighten`) runs Auto through the catalog on `LiveCrop`. The
// live leveler is nil until CR-10 conforms `LiveCrop` over core's horizon
// detector, so the suite is disabled until then. Runs on Linux and macOS.
import Foundation
import Testing
import CoreRaster

@testable import LibraryModel

/// The shoot fixture's photo `IMG_<n>` (ids are paths).
private func shot(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

/// The live services over the fakes' platform adapters.
private func liveServices() -> LibraryServices {
    let fake = LibraryServices.fake()
    return LibraryServices.live(decoder: fake.decoder, writer: fake.writer, store: fake.store)
}

/// The live services' leveler; fails the test while it is nil.
private func liveLeveler() throws -> any CropLeveling {
    try #require(LibraryCatalog(services: liveServices()).leveler)
}

/// A `width` × `height` buffer, light sky over dark ground. The boundary
/// crosses the center and rises `degrees` to the right (negative falls).
private func horizon(rising degrees: Double, width: Int = 1200, height: Int = 800) throws -> PixelBuffer {
    let slope = tan(degrees * .pi / 180)
    let midX = Double(width) / 2, midY = Double(height) / 2
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            // Image rows grow downward, so a rising edge has a smaller y to the right.
            let edge = midY - slope * (Double(x) + 0.5 - midX)
            let tone: UInt8 = Double(y) + 0.5 < edge ? 220 : 40
            let i = (y * width + x) * 4
            bytes[i] = tone; bytes[i + 1] = tone; bytes[i + 2] = tone
        }
    }
    return try PixelBuffer(rgba8: bytes, width: width, height: height)
}

/// One flat color, no horizon.
private func flat(width: Int = 1200, height: Int = 800) throws -> PixelBuffer {
    try PixelBuffer(rgba8: [UInt8](repeating: 128, count: width * height * 4), width: width, height: height)
}

/// The shoot on the fakes with the live crop and leveler, `IMG_<n>` in the loupe.
private func liveCropLoupe(_ n: Int = 1) -> LibraryCatalog {
    var services = LibraryServices.fake()
    let live = liveServices()
    services.crop = live.crop
    services.leveler = live.leveler
    var catalog = LibraryCatalog(services: services)
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    catalog.open(shot(n))
    return catalog
}

@Suite(.disabled("waits on CR-10"))
struct LibraryCropLevelTests {
    @Test func aHorizonRisingThreeDegreesLevelsByThree() throws {
        let angle = try #require(try liveLeveler().levelAngle(horizon(rising: 3)))
        #expect(abs(angle - 3.0) <= 0.3)
    }

    @Test func aHorizonFallingSevenDegreesLevelsByMinusSeven() throws {
        let angle = try #require(try liveLeveler().levelAngle(horizon(rising: -7)))
        #expect(abs(angle - -7.0) <= 0.3)
    }

    @Test func aFlatBufferHasNoHorizon() throws {
        #expect(try liveLeveler().levelAngle(flat()) == nil)
    }

    @Test func liveServicesCanLevel() {
        let catalog = LibraryCatalog(services: liveServices())
        #expect(catalog.leveler != nil)
        #expect(catalog.levelHelp == nil)
    }

    /// MJ6A: Auto on a tilted photo through the catalog, then Apply.
    @Test func walkAutoStraighten() throws {
        var catalog = liveCropLoupe()
        // 1. R opens the whole photo at 0°.
        catalog.beginCrop()
        let before = try #require(catalog.cropFrame)
        #expect(catalog.cropDraft?.angle == 0)
        // 2. Auto: the leveler reads the tilt, the catalog adds it.
        let leveler = try #require(catalog.leveler)
        let delta = try leveler.levelAngle(horizon(rising: 3))
        catalog.levelCrop(by: delta)
        // 3. Straighten reads 3.0 and the frame shrank to fit inside the turned photo.
        let angle = try #require(catalog.cropDraft?.angle)
        #expect(abs(angle - 3.0) <= 0.3)
        let after = try #require(catalog.cropFrame)
        #expect(after.width < before.width)
        #expect(after.height < before.height)
        // 4. Apply records one "Crop" step and stores the angle.
        catalog.applyCrop()
        #expect(catalog.cropDraft == nil)
        #expect(catalog.undoTitle == "Undo Crop")
        let stored = try #require(catalog.loupeItem?.develop.crop)
        #expect(abs(stored.angle - 3.0) <= 0.3)
    }
}
