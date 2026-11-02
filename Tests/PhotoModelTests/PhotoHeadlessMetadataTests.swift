// PhotoHeadlessMetadataTests.swift: the CLI's Photo export keeps the opened JPEG's metadata by the `metadata`
// option (export-pack quality gate #5834, #5975), through SuiteImaging's Linux-safe `JPEGMetadata`.
// The fixture, Tests/RealJobs/fixtures/gps-phone.jpg, carries GPS, Make, Model, Copyright, DateTimeOriginal,
// a body serial number and Orientation 6.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import PhotoModel
import SuiteImaging
import SuiteKernel
import Testing

@Suite struct PhotoHeadlessMetadataTests {
    static let source: Data? = try? Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appending(path: "RealJobs/fixtures/gps-phone.jpg"))

    func exported(_ metadata: String, format: String = "jpeg") throws -> Data {
        let source = try #require(Self.source)
        let document = try PhotoHeadless.open(source, name: "gps-phone.jpg")
        let files = try document.export(format, options: .object(["metadata": .string(metadata)]))
        return try #require(files.first).data
    }

    @Test func allKeepsLocationCameraAndDateUpright() throws {
        let out = try exported("all")
        let paths = try JPEGMetadata().properties(of: out)
        #expect(paths.isSuperset(of: ["{GPS}", "{TIFF}.Make", "{TIFF}.Model", "{TIFF}.Copyright",
                                      "{Exif}.DateTimeOriginal", "{Exif}.BodySerialNumber"]))
        #expect(try JPEG.info(out).orientation == 1)
    }

    @Test func noLocationDropsGPSAndSerialsButKeepsTheRest() throws {
        let out = try exported("noLocation")
        let paths = try JPEGMetadata().properties(of: out)
        #expect(!paths.contains("{GPS}"))
        #expect(!paths.contains("{Exif}.BodySerialNumber"))
        #expect(paths.isSuperset(of: ["{TIFF}.Make", "{Exif}.DateTimeOriginal"]))
        #expect(out.range(of: Data("SN-0042-BODY".utf8)) == nil)
        #expect(try JPEG.info(out).orientation == 1)
    }

    @Test func noneKeepsNothingIdentifying() throws {
        let out = try exported("none")
        let paths = try JPEGMetadata().properties(of: out)
        #expect(paths.isDisjoint(with: ["{GPS}", "{TIFF}.Make", "{TIFF}.Model", "{TIFF}.Copyright", "{Exif}"]))
        #expect(out.range(of: Data("Phone One".utf8)) == nil)
    }

    @Test func aPNGExportStillWrites() throws {
        let out = try exported("all", format: "png")
        #expect(try PNG.info(out).width > 0)
    }

    @Test func anUnreadableSourceCopiesNothing() throws {
        let still = try exported("none")
        #expect(try JPEGMetadata().carrying(still, from: Data([1, 2, 3]), dropping: []) == still)
    }
}
