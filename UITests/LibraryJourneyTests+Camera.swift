// LibraryJourneyTests+Camera.swift: MD-J1, the Info tab's Camera section (metadata-more).
// Steps 1-3 run on the `cameras` fixture; step 4 imports a.jpg (Exif) and b.png (none).
// Written before its code (contract rule 13, MD-5); MD-8 turned every step on.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class LibraryCameraJourneyTests: XCTestCase {
    /// One photo's rows in order with step 1's texts (Taken is a date).
    static let oneRows: [(field: String, text: String?)] = [
        ("camera", "Fixture Optics FX-1"), ("lens", "24-70mm F2.8"), ("aperture", "f/2.8"),
        ("shutter", "1/2000 s"), ("iso", "ISO 100"), ("focalLength", "24 mm"), ("taken", nil),
    ]
    private var library: Journey?
    private var skipped: [String] = []

    @MainActor func testCameraDetailsInInfo() throws {
        skipped = []
        try step("1") { try self.onePhoto() }
        try step("2") { try self.range() }
        try step("3") { try self.noDetails() }
        library?.app.terminate()
        try step("4") { try self.livePass() }
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }

    @MainActor private func step(_ name: String, _ body: () throws -> Void) throws {
        do { try body() } catch let skip as XCTSkip { skipped.append("step \(name): \(skip.message ?? "skipped")") }
    }

    /// Step 1: by name, click IMG_0001: the seven rows in `CameraField` order.
    @MainActor private func onePhoto() throws {
        let library = Journey("Library", self, arguments: ["-LibraryFixture", "cameras"])
        self.library = library
        sortByName(library)
        cell("IMG_0001", library).click()
        let rows = Self.oneRows.map { row($0.field, library) }
        XCTAssert(rows[0].waitForExistence(timeout: 5), "no Camera row (library.metadata.camera.camera)")
        library.shot("camera-one")
        for ((field, want), element) in zip(Self.oneRows, rows) {
            XCTAssert(element.exists, "no \(field) row (library.metadata.camera.\(field))")
            if let want { XCTAssertEqual(Self.text(element), want, "the \(field) row") }
        }
        let tops = rows.map(\.frame.minY)
        XCTAssertEqual(tops, tops.sorted(), "the rows aren't in CameraField order")
    }

    /// Step 2: Shift-click IMG_0006: "2 cameras" and "ISO 100–3200".
    @MainActor private func range() throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        let last = cell("IMG_0006", library)
        XCUIElement.perform(withKeyModifiers: .shift) { last.click() }
        let counted = NSPredicate(format: "value == %@", "2 cameras")
        wait(for: [expectation(for: counted, evaluatedWith: row("camera", library))], timeout: 5)
        library.shot("camera-range")
        XCTAssertEqual(Self.text(row("iso", library)), "ISO 100–3200", "the ISO row")
    }

    /// Step 3: click IMG_0024 (no Exif): "No camera details" and no rows.
    @MainActor private func noDetails() throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        cell("IMG_0024", library).click()
        XCTAssert(library.app.staticTexts["No camera details"].waitForExistence(timeout: 5), "no \"No camera details\"")
        library.shot("camera-none")
        for (field, _) in Self.oneRows { XCTAssertFalse(row(field, library).exists, "IMG_0024 shows a \(field) row") }
    }

    /// Step 4 (L): a.jpg's Exif shows in the rows; b.png reads "No camera details".
    @MainActor private func livePass() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { [folder, catalog].forEach { try? FileManager.default.removeItem(at: $0) } }
        try Self.write(folder.appending(path: "a.jpg"), .jpeg, properties: Self.cameraExif)
        try Self.write(folder.appending(path: "b.png"), .png, properties: [:])
        let library = Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryImportOnLaunch", "-LibraryCatalogDir", catalog.path,
        ])
        defer { library.app.terminate() }
        XCTAssert(cell("/a.jpg", library).waitForExistence(timeout: 30), "a.jpg wasn't imported")
        cell("/a.jpg", library).click()
        XCTAssert(row("camera", library).waitForExistence(timeout: 5), "no Camera row for a.jpg")
        library.shot("camera-live")
        let want = [("camera", "Test Maker TM-10"), ("lens", "35mm F1.4"), ("aperture", "f/2"),
                    ("shutter", "1/250 s"), ("iso", "ISO 800"), ("focalLength", "35 mm")]
        for (field, text) in want { XCTAssertEqual(Self.text(row(field, library)), text, "a.jpg's \(field) row") }
        cell("/b.png", library).click()
        XCTAssert(library.app.staticTexts["No camera details"].waitForExistence(timeout: 5), "b.png shows camera details")
    }

    static var cameraExif: [CFString: Any] {
        let exif: [CFString: Any] = [
            kCGImagePropertyExifLensModel: "35mm F1.4", kCGImagePropertyExifISOSpeedRatings: [800],
            kCGImagePropertyExifExposureTime: 0.004, kCGImagePropertyExifFNumber: 2.0,
            kCGImagePropertyExifFocalLength: 35.0, kCGImagePropertyExifDateTimeOriginal: "2026:06:01 10:00:00",
        ]
        let tiff: [CFString: Any] = [kCGImagePropertyTIFFMake: "Test Maker", kCGImagePropertyTIFFModel: "TM-10"]
        return [kCGImagePropertyExifDictionary: exif, kCGImagePropertyTIFFDictionary: tiff]
    }

    static func write(_ url: URL, _ type: UTType, properties: [CFString: Any]) throws {
        let failed = LibraryFiles.WriteError(description: "can't write \(url.lastPathComponent)")
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw failed }
        context.setFillColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 64, height: 48))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil)
        else { throw failed }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw failed }
    }

    /// The Camera section's row for `field`.
    @MainActor private func row(_ field: String, _ library: Journey) -> XCUIElement {
        library.element("library.metadata.camera.\(field)")
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id contains `name`.
    @MainActor private func cell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }

    /// Waits for IMG_0024's cell, then View > Sort By > Name.
    @MainActor private func sortByName(_ library: Journey) {
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        sort.menuItems["Name"].click()
    }

    /// What an element reads: its value where macOS puts a row's text, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }
}
