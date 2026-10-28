// LibraryJourneyTests+ExportPack.swift: LJ-X1, export without location
// (packet docs/blueprints/library/features/export-pack.md, Journey steps;
// slice LX-u, task LX-6). Its own XCTestCase class, like +Export.swift. All
// live: one GPS-tagged phone JPEG this file writes (GPS, camera model, capture
// date, copyright), imported on launch into a fresh `-LibraryCatalogDir`, with
// `-LibraryExportTo` on a fresh temp folder, so Export writes there without a
// panel. The Metadata row's chips are LX-2's (`library.export.metadata.<policy>`);
// the summary is EX-6's `library.export.summary`; the buttons and the Write
// Sidecar checkbox are found by title.
//
// Written before its code (lead.md, contract rule 13, LX-6); on since LX-7,
// with LX-3 and LX-4 writing the policy into the sidecar and the JPEG.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class LibraryExportPackJourneyTests: XCTestCase {
    /// LJ-X1: All but location keeps the camera and the date and drops the GPS;
    /// None drops the date too, from the JPEG and its sidecar alike.
    @MainActor func testExportWithoutLocation() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        let out = try LibraryFiles.freshPhotoFolder()
        addTeardownBlock { for url in [folder, catalog, out] { try? FileManager.default.removeItem(at: url) } }
        try Self.writePhonePhoto(to: folder.appending(path: "gps-phone.jpg"))
        let library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryImportOnLaunch",
            "-LibraryCatalogDir", catalog.path, "-LibraryExportTo", out.path,
        ])

        // Step 1: select the phone photo, File > Export…: Metadata reads All but location.
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let cell = gridCell("gps-phone", library)
        XCTAssert(cell.waitForExistence(timeout: 60), "no grid cell for gps-phone")
        cell.click()
        openSheetWithSidecar(library)
        let noLocation = library.element("library.export.metadata.noLocation")
        XCTAssert(noLocation.waitForExistence(timeout: 3), "the sheet has no All but location chip")
        XCTAssert(noLocation.isSelected, "Metadata doesn't read All but location")
        library.shot("export-metadata")

        // Step 2: Write Sidecar on, Export: the JPEG and its .xmp are written.
        export(library)
        let jpeg = out.appending(path: "gps-phone.jpg"), xmp = out.appending(path: "gps-phone.xmp")
        XCTAssert(FileManager.default.fileExists(atPath: jpeg.path), "Export wrote no gps-phone.jpg")
        XCTAssert(FileManager.default.fileExists(atPath: xmp.path), "Export wrote no gps-phone.xmp")

        // Step 3: the JPEG keeps its camera model and capture date and has no GPS; the sidecar has no GPS.
        let kept = try Self.properties(jpeg)
        let tiff = kept[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = kept[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        XCTAssertEqual(tiff[kCGImagePropertyTIFFModel] as? String, Self.model, "the JPEG lost its camera model")
        XCTAssertEqual(exif[kCGImagePropertyExifDateTimeOriginal] as? String, Self.captured, "the JPEG lost its capture date")
        XCTAssertNil(kept[kCGImagePropertyGPSDictionary], "the JPEG carries GPS under All but location")
        let packet = try String(contentsOf: xmp, encoding: .utf8)
        XCTAssertFalse(packet.contains("GPS"), "gps-phone.xmp carries GPS under All but location: \(packet)")

        // Step 4: export again with None: neither file has a capture date.
        closeSheet(library)
        openSheetWithSidecar(library)
        let none = library.element("library.export.metadata.none")
        XCTAssert(none.waitForExistence(timeout: 3), "the sheet has no None chip")
        none.click()
        XCTAssert(none.isSelected, "Metadata doesn't read None after the click")
        export(library)
        let bare = try Self.properties(out.appending(path: "gps-phone 2.jpg"))
        let bareExif = bare[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        XCTAssertNil(bareExif[kCGImagePropertyExifDateTimeOriginal], "the JPEG keeps its capture date under None")
        XCTAssertNil(bare[kCGImagePropertyGPSDictionary], "the JPEG carries GPS under None")
        let barePacket = try String(contentsOf: out.appending(path: "gps-phone 2.xmp"), encoding: .utf8)
        XCTAssertFalse(barePacket.contains("DateTimeOriginal") || barePacket.contains("DateCreated"),
                       "gps-phone 2.xmp keeps a capture date under None: \(barePacket)")
        library.shot("export-metadata-none")
        closeSheet(library)
        library.app.terminate()
    }

    // MARK: - Steps

    /// File > Export…, which must be enabled, then the Write Sidecar checkbox on.
    @MainActor private func openSheetWithSidecar(_ library: Journey) {
        let file = library.app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssert(file.waitForExistence(timeout: 5), "no File menu")
        file.click()
        let item = file.menuItems["Export…"]
        XCTAssert(item.waitForExistence(timeout: 3), "the File menu has no Export…")
        XCTAssert(item.isEnabled, "File > Export… is disabled with the phone photo selected")
        item.click()
        let sheet = library.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 5), "File > Export… opened no sheet")
        let sidecar = sheet.checkBoxes.matching(NSPredicate(format: "label == %@", "Write Sidecar")).firstMatch
        XCTAssert(sidecar.waitForExistence(timeout: 3), "the sheet has no Write Sidecar checkbox")
        XCTAssert(sidecar.isEnabled, "Write Sidecar is disabled")
        if (sidecar.value as? Int ?? 0) == 0 { sidecar.click() }
        XCTAssertEqual(sidecar.value as? Int, 1, "Write Sidecar didn't turn on")
    }

    /// Export, then the summary "Exported 1 photo.".
    @MainActor private func export(_ library: Journey) {
        sheetButton("Export", library).click()
        let summary = library.element("library.export.summary")
        XCTAssert(summary.waitForExistence(timeout: 60), "no summary (library.export.summary)")
        XCTAssertEqual(Self.text(summary), "Exported 1 photo.", "the summary")
    }

    // MARK: - Helpers

    /// The sample's camera model and capture date, which All but location keeps.
    private static let model = "Phone Camera 12", captured = "2026:05:02 10:15:00"

    /// A 1600 × 1200 JPEG at `url` tagged as a phone shot: GPS, camera model, capture date and copyright.
    private static func writePhonePhoto(to url: URL) throws {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: 1600, height: 1200, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw LibraryFiles.WriteError(description: "no 1600 × 1200 context for gps-phone.jpg") }
        context.setFillColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1600, height: 1200))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        let image = try XCTUnwrap(context.makeImage(), "no image for gps-phone.jpg")
        let target = try XCTUnwrap(destination, "can't write gps-phone.jpg")
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: captured, kCGImagePropertyExifOffsetTimeOriginal: "+00:00",
            ] as [CFString: Any],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "Phone Maker", kCGImagePropertyTIFFModel: model,
                kCGImagePropertyTIFFCopyright: "© 2026 Sample Owner",
            ] as [CFString: Any],
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 37.7749, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 122.4194, kCGImagePropertyGPSLongitudeRef: "W",
            ] as [CFString: Any],
            kCGImageDestinationLossyCompressionQuality: 0.6,
        ]
        CGImageDestinationAddImage(target, image, properties as CFDictionary)
        XCTAssert(CGImageDestinationFinalize(target), "couldn't finish gps-phone.jpg")
    }

    /// The image properties of the file at `url`.
    private static func properties(_ url: URL) throws -> [CFString: Any] {
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil), "\(url.lastPathComponent) isn't an image")
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
    }

    /// The sheet's Done or Close button, then the sheet is gone.
    @MainActor private func closeSheet(_ library: Journey) {
        let sheet = library.app.sheets.firstMatch
        guard sheet.exists else { return }
        let button = ["Done", "Close"].lazy.map { self.sheetButton($0, library) }.first { $0.exists }
        XCTAssertNotNil(button, "the export sheet has no Done or Close")
        button?.click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "the export sheet didn't close")
    }

    /// The sheet's button titled `title`.
    @MainActor private func sheetButton(_ title: String, _ library: Journey) -> XCUIElement {
        library.app.sheets.firstMatch.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func gridCell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }

    /// What an element reads: its value where macOS puts a field's text, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }
}
