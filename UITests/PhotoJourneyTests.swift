// PhotoJourneyTests.swift: Photo driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). The core
// journey opens a real PNG (written by the test, passed with
// -PhotoOpenFile), paints a stroke, undoes it, raises the exposure and
// exports a PNG (to the folder given with -PhotoExportTo, so no save panel),
// then checks the file is a PNG. Another journey edits with every other tool.
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Photo", self).expectEditorShell()
    }

    @MainActor func testNewImageAndEveryTool() {
        let photo = Journey("Photo", self)
        photo.app.typeKey("n", modifierFlags: .command)
        photo.shot("new-image")
        photo.clickEachTool()
    }

    @MainActor func testEveryMenuOpens() {
        let photo = Journey("Photo", self)
        photo.app.typeKey("n", modifierFlags: .command)
        photo.openEachMenu()
    }

    @MainActor func testOpenImagePaintAndSave() throws {
        let folder = try Self.folder()
        let exports = folder.appending(path: "exports")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        let file = folder.appending(path: "journey.png")
        try Self.writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: ["-PhotoOpenFile", file.path, "-PhotoExportTo", exports.path])
        XCTAssert(photo.app.windows["journey.png"].waitForExistence(timeout: 30), "journey.png didn't open")
        photo.shot("opened")

        photo.element("suite.tools").buttons["Brush"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.3), to: CGVector(dx: 0.8, dy: 0.7), step: "painted")
        photo.click("Undo Paint", in: .window, step: "undone")
        XCTAssert(photo.app.buttons["Redo Paint"].waitForExistence(timeout: 5), "Undo didn't undo the stroke")

        let exposure = photo.app.sliders["Exposure"]
        XCTAssert(exposure.waitForExistence(timeout: 5), "no Exposure slider")
        exposure.adjust(toNormalizedSliderPosition: 0.65)
        photo.shot("exposure")

        photo.click("Export", in: .window, step: "export-sheet")
        photo.click("Export", in: .sheet)
        let exported = exports.appending(path: "journey.png")
        XCTAssert(Self.waitForFile(exported), "Export wrote no file")
        let header = try Data(contentsOf: exported).prefix(8)
        XCTAssertEqual(Array(header), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "the export isn't a PNG")
        photo.shot("exported")
    }

    @MainActor func testEveryToolEditsTheImage() throws {
        let file = try Self.folder().appending(path: "tools.png")
        try Self.writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: ["-PhotoOpenFile", file.path])
        XCTAssert(photo.app.windows["tools.png"].waitForExistence(timeout: 30), "tools.png didn't open")
        let tools = photo.element("suite.tools").buttons

        tools["Eraser"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.1, dy: 0.8), to: CGVector(dx: 0.5, dy: 0.5), step: "erased")

        tools["Marquee"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.55, dy: 0.15), to: CGVector(dx: 0.85, dy: 0.45), step: "selected")
        photo.click("Fill", in: .window, step: "filled")

        tools["Move"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.5, dy: 0.5), to: CGVector(dx: 0.6, dy: 0.55), step: "moved")

        tools["Crop"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.1, dy: 0.1), to: CGVector(dx: 0.9, dy: 0.9), step: "crop-pending")
        photo.click("Apply Crop", in: .window, step: "cropped")
        XCTAssert(photo.app.buttons["Undo Crop"].waitForExistence(timeout: 5), "the crop wasn't applied")
    }

    /// A fresh folder for one journey's files.
    private static func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-journey-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// An 800 x 600 PNG that reads like a photo: a sky gradient and a sun.
    private static func writeTestPhoto(to url: URL) throws {
        let (width, height) = (800, 600)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let gradient = CGGradient(
                colorsSpace: space,
                colors: [CGColor(srgbRed: 0.16, green: 0.42, blue: 0.86, alpha: 1),
                         CGColor(srgbRed: 0.98, green: 0.62, blue: 0.42, alpha: 1)] as CFArray,
                locations: [0, 1])
        else { throw CocoaError(.fileWriteUnknown) }
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
        context.setFillColor(CGColor(srgbRed: 1, green: 0.86, blue: 0.3, alpha: 1))
        context.fillEllipse(in: CGRect(x: 470, y: 290, width: 180, height: 180))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// Waits up to 15 seconds for `url` to exist.
    private static func waitForFile(_ url: URL) -> Bool {
        for _ in 0..<30 {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }
}
