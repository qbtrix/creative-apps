// LibraryCropLevelingTests.swift: the Auto slot (CR-2). The catalog's
// `leveler` is the services' optional `CropLeveling`; `levelHelp` says why
// Auto can't run until one is set. The fake levels any image that isn't one
// flat color by 2.5 degrees and finds no horizon in a flat one.
import Foundation
import Testing
import CoreRaster

@testable import LibraryModel

private func flat(width: Int = 8, height: Int = 6) throws -> PixelBuffer {
    try PixelBuffer(rgba8: [UInt8](repeating: 128, count: width * height * 4), width: width, height: height)
}

private func twoTone(width: Int = 8, height: Int = 6) throws -> PixelBuffer {
    var bytes = [UInt8](repeating: 255, count: width * height * 4)
    for i in 0..<(width * (height / 2) * 4) where i % 4 != 3 { bytes[i] = 20 }
    return try PixelBuffer(rgba8: bytes, width: width, height: height)
}

@Test func fakeLevelsANonFlatImageByTwoAndAHalfDegrees() throws {
    #expect(try FakeCrop().levelAngle(twoTone()) == 2.5)
}

@Test func fakeFindsNoHorizonInAFlatImage() throws {
    #expect(try FakeCrop().levelAngle(flat()) == nil)
}

@Test func fakeSeesOneDifferentPixelAsNotFlat() throws {
    var bytes = [UInt8](repeating: 128, count: 4 * 4 * 4)
    bytes[bytes.count - 2] = 0
    #expect(try FakeCrop().levelAngle(PixelBuffer(rgba8: bytes, width: 4, height: 4)) == 2.5)
}

@Test func fakeServicesCanLevel() throws {
    let catalog = LibraryCatalog(services: .fake())
    #expect(catalog.leveler != nil)
    #expect(catalog.levelHelp == nil)
    #expect(try catalog.leveler?.levelAngle(twoTone()) == 2.5)
}

@Test func servicesWithoutALevelerSayWhyAutoCantRun() {
    var services = LibraryServices.fake()
    services.leveler = nil
    let catalog = LibraryCatalog(services: services)
    #expect(catalog.leveler == nil)
    #expect(catalog.levelHelp == "Auto-straighten isn't connected yet (crop).")
}

@Test func liveServicesHaveNoLevelerYet() {
    let fake = LibraryServices.fake()
    let live = LibraryServices.live(decoder: fake.decoder, writer: fake.writer, store: fake.store)
    #expect(live.leveler == nil)
    #expect(LibraryCatalog(services: live).levelHelp == "Auto-straighten isn't connected yet (crop).")
}

@Test func levelerDefaultsToNilInTheInitializer() {
    let f = LibraryServices.fake()
    let services = LibraryServices(decoder: f.decoder, importer: f.importer, thumbnails: f.thumbnails,
                                   culling: f.culling, coding: f.coding, store: f.store, loupe: f.loupe,
                                   develop: f.develop, crop: f.crop, exporter: f.exporter, writer: f.writer,
                                   isPreview: true)
    #expect(services.leveler == nil)
}
