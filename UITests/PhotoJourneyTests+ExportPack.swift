// PhotoJourneyTests+ExportPack.swift: PJ-X1, export for a 4:5 post
// (docs/blueprints/photo/features/export-pack.md, Journey steps). A 6000 x
// 4000 photo is cropped to 3200 x 4000 by the crop fields and applied, then
// File > Export… opens the suite's sheet with PNG, JPEG, HEIC and TIFF
// (`photo.export.format.<id>`). JPEG with Size > Pixels 1080 reads a height of
// 1350 and writes `photo.jpg` at 1080 x 1350; HEIC at Long edge 2048 writes
// 1638 x 2048. Written before its code (PX-6): the Size row's Pixels and Long
// edge modes come with suiteui export-pack XP-3/XP-4 and the sized write with
// PX-4, so every step skips until PX-7 turns it on and checks the row's ids
// (`photo.export.size.width`, `.height`, `.longEdge`) against XP-4's.
import CoreGraphics
import ImageIO
import XCTest

final class PhotoExportPackJourneyTests: XCTestCase {
    /// PJ-X1: crop to 4:5, export JPEG at 1080 x 1350, then HEIC at long edge 2048.
    @MainActor func testExportForInstagram() throws {
        throw XCTSkip("waits on PX-7")
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-export-pack-\(UUID().uuidString)")
        let exports = folder.appending(path: "out")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "photo.png")
        try writeTestPhoto(to: file, width: 6000, height: 4000)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file, exportTo: exports))
        XCTAssert(photo.window(named: "photo.png").waitForExistence(timeout: 30), "photo.png didn't open")

        // 1. Crop to 3200 x 4000 (4:5), apply, then Export… shows the four formats.
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        canvas.click()
        photo.press(character: "c")
        type(3200, into: "photo.crop.width", photo)
        type(4000, into: "photo.crop.height", photo)
        type(1400, into: "photo.crop.x", photo)
        type(0, into: "photo.crop.y", photo)
        canvas.click()
        photo.app.typeKey(.return, modifierFlags: [])
        photo.click("Export", in: .window, step: "export-pack-sheet")
        for format in ["png", "jpeg", "heic", "tiff"] {
            let chip = photo.element("photo.export.format.\(format)")
            XCTAssert(chip.waitForExistence(timeout: 5) && chip.isEnabled, "the sheet has no working \(format) chip")
        }

        // 2. JPEG, Size > Pixels, width 1080: height reads 1350; Export writes 1080 x 1350.
        photo.element("photo.export.format.jpeg").click()
        photo.app.sheets.buttons["Pixels"].click()
        type(1080, into: "photo.export.size.width", photo)
        let height = photo.element("photo.export.size.height")
        XCTAssert(Self.waitUntil { "\(height.value ?? "")".contains("1350") }, "the height doesn't read 1350")
        photo.shot("export-pack-pixels")
        photo.click("Export", in: .sheet)
        XCTAssertEqual(Self.pixels(exports.appending(path: "photo.jpg")), [1080, 1350], "photo.jpg isn't 1080 x 1350")

        // 3. HEIC at Long edge 2048 writes 1638 x 2048.
        photo.click("Export", in: .window)
        photo.element("photo.export.format.heic").click()
        photo.app.sheets.buttons["Long edge"].click()
        type(2048, into: "photo.export.size.longEdge", photo)
        photo.shot("export-pack-long-edge")
        photo.click("Export", in: .sheet)
        XCTAssertEqual(Self.pixels(exports.appending(path: "photo.heic")), [1638, 2048], "photo.heic isn't 1638 x 2048")
    }

    /// Clicks the number field `id`, replaces its text with `value` and presses Return.
    @MainActor private func type(_ value: Int, into id: String, _ photo: Journey) {
        let field = photo.element(id)
        XCTAssert(field.waitForExistence(timeout: 5) && field.isEnabled, "no field \(id) to type in")
        field.click()
        photo.app.typeKey("a", modifierFlags: .command)
        photo.app.typeText("\(value)")
        photo.app.typeKey(.return, modifierFlags: [])
    }

    /// The written file's width and height, once it exists; empty when none came within 15 s.
    private static func pixels(_ url: URL) -> [Int] {
        guard waitUntil({ FileManager.default.fileExists(atPath: url.path) }, timeout: 15),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return [] }
        return [image.width, image.height]
    }

    private static func waitUntil(_ condition: () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }
}
