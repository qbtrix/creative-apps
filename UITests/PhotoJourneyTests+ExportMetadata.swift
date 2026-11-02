// PhotoJourneyTests+ExportMetadata.swift: export-pack quality gate #5834
// (bug 2) in the built app. Photo opens the sample phone photo
// (`Tests/RealJobs/fixtures/gps-phone.jpg`: GPS, make, model, capture date,
// copyright) with -PhotoOpenFile, exports it as JPEG to -PhotoExportTo (no
// panel), and the written file still carries those tags, read back with
// ImageIO. The orientation is not carried: the open already turned the pixels
// upright. One shot per step, `photo-export-metadata-<step>`.
import ImageIO
import XCTest

final class PhotoExportMetadataJourneyTests: XCTestCase {
    @MainActor func testExportKeepsTheSourcesMetadata() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-export-metadata-\(UUID().uuidString)")
        let exports = folder.appending(path: "exports")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let sample = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Tests/RealJobs/fixtures/gps-phone.jpg")
        let file = folder.appending(path: "gps-phone.jpg")
        try FileManager.default.copyItem(at: sample, to: file)

        let photo = Journey("Photo", self, arguments: photoArguments(open: file, exportTo: exports))
        XCTAssert(photo.window(named: "gps-phone.jpg").waitForExistence(timeout: 30), "gps-phone.jpg didn't open")
        photo.shot("export-metadata-opened")

        photo.click("Export", in: .window, step: "export-metadata-sheet")
        let jpeg = photo.element("photo.export.format.jpeg")
        XCTAssert(jpeg.waitForExistence(timeout: 5), "the Export sheet has no JPEG choice")
        jpeg.click()
        photo.click("Export", in: .sheet)
        let exported = exports.appending(path: "gps-phone.jpg")
        var written: [CFString: Any] = [:]
        for _ in 0..<40 where written[kCGImagePropertyTIFFDictionary] == nil {
            Thread.sleep(forTimeInterval: 0.5)
            written = CGImageSourceCreateWithURL(exported as CFURL, nil)
                .flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [CFString: Any] } ?? [:]
        }
        photo.shot("export-metadata-exported")

        let tiff = written[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = written[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        XCTAssertNotNil(written[kCGImagePropertyGPSDictionary], "the export dropped the GPS location")
        XCTAssertNotNil(tiff[kCGImagePropertyTIFFMake], "the export dropped the camera make")
        XCTAssertNotNil(tiff[kCGImagePropertyTIFFModel], "the export dropped the camera model")
        XCTAssertNotNil(tiff[kCGImagePropertyTIFFCopyright], "the export dropped the copyright")
        XCTAssertNotNil(exif[kCGImagePropertyExifDateTimeOriginal], "the export dropped the capture date")
        let orientation = (written[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        XCTAssertEqual(orientation, 1, "the export carried an orientation onto upright pixels")
    }
}
