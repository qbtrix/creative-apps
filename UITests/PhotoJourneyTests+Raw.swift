// PhotoJourneyTests+Raw.swift: PJ-SR (suiteui/shared-raw; SR-5 writes it skipped, SR-7 turns it on live),
// opening a camera RAW file in Photo as a person does (docs/blueprints/suiteui/features/shared-raw.md, Journey
// steps):
// 1. `tiny-bayer.dng` and `not-raw.nef` (SuiteImagingTests' raw fixtures, by #filePath) go into a temp
//    folder. Photo launches on `not-raw.nef`: the open-failure alert reads "macOS can't read this raw file
//    (NEF)." and the window stays empty. Shot `photo-open-raw-refused`.
// 2. Photo opens `tiny-bayer.dng`: the title is "tiny-bayer", the canvas 48 x 64 (Orientation 6 applied),
//    one layer "Background". Shot `photo-open-raw`.
// 3. Exposure dragged to -1 in the tone rows (its slider runs -5...5, so 0.4 of the way).
// 4. Export as PNG (-PhotoExportTo): the file is 48 x 64, not the embedded preview's 24 x 32, and its two
//    highlight patches are more than 20 levels apart (an 8-bit decode leaves both at white).
import CoreGraphics
import ImageIO
import XCTest

final class PhotoRawJourneyTests: XCTestCase {
    /// SuiteImagingTests' raw fixtures, which SR-1's TinyDNG writer produced.
    private static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Tests/SuiteImagingTests/Fixtures/raw")

    @MainActor func testOpenRawDevelopExport() throws {
        try XCTSkipIf(true, "waits on SR-7")
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-raw-\(UUID().uuidString)")
        let exports = folder.appending(path: "exports")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let dng = folder.appending(path: "tiny-bayer.dng"), nef = folder.appending(path: "not-raw.nef")
        try FileManager.default.copyItem(at: Self.fixtures.appending(path: "tiny-bayer.dng"), to: dng)
        try FileManager.default.copyItem(at: Self.fixtures.appending(path: "not-raw.nef"), to: nef)

        let refused = Journey("Photo", self, arguments: photoArguments(open: nef)) // 1.
        let sheet = refused.app.sheets.firstMatch.waitForExistence(timeout: 30)
            ? refused.app.sheets.firstMatch : refused.app.dialogs.firstMatch
        let sentence = "macOS can't read this raw file (NEF)."
        let message = sheet.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", sentence, sentence))
        XCTAssert(message.firstMatch.waitForExistence(timeout: 10), "opening not-raw.nef showed no refusal sentence")
        refused.shot("photo-open-raw-refused")
        sheet.buttons["OK"].click()
        XCTAssertFalse(refused.element("suite.canvas").waitForExistence(timeout: 2), "the refused file left a canvas")
        refused.app.terminate()

        let photo = Journey("Photo", self, arguments: photoArguments(open: dng, exportTo: exports)) // 2.
        XCTAssert(photo.window(named: "tiny-bayer").waitForExistence(timeout: 30), "tiny-bayer.dng didn't open")
        XCTAssertFalse(photo.window(named: "tiny-bayer.dng").exists, "the window names the RAW file, not tiny-bayer")
        let size = photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "48 × 64 px"))
        XCTAssert(size.firstMatch.waitForExistence(timeout: 5), "the header doesn't read 48 × 64 px")
        XCTAssert(photo.app.staticTexts["Background"].waitForExistence(timeout: 5), "the layer list lists no Background")
        photo.shot("photo-open-raw")

        let exposure = photo.app.sliders["Exposure"] // 3.
        XCTAssert(exposure.waitForExistence(timeout: 10), "no Exposure slider in the tone rows")
        exposure.adjust(toNormalizedSliderPosition: 0.4)
        XCTAssert(photo.app.buttons["Undo Exposure"].waitForExistence(timeout: 5), "the drag made no Exposure step")

        photo.click("Export", in: .window) // 4.
        photo.click("Export", in: .sheet)
        let exported = exports.appending(path: "tiny-bayer.png")
        XCTAssert(waitForFile(exported), "Export wrote no tiny-bayer.png")
        let (width, height, levels) = try highlightLevels(exported)
        XCTAssertEqual([width, height], [48, 64], "the export is \(width) x \(height), not 48 x 64")
        XCTAssertGreaterThan(abs(levels[1] - levels[0]), 20, "the highlight patches read \(levels): clipped before Exposure")
    }

    /// The PNG's size and the red level at each highlight patch's centre. The patches sit at (8, 8) and
    /// (40, 8), 16 px square, in the stored 64 x 48 frame; Orientation 6 turns a stored (x, y) to (47 - y, x).
    private func highlightLevels(_ url: URL) throws -> (Int, Int, [Int]) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let data = context.data
        else { throw CocoaError(.fileReadCorruptFile) }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = data.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        let levels = [(16, 16), (48, 16)].map { stored -> Int in
            let (x, y) = (47 - stored.1, stored.0)
            guard x < image.width, y < image.height else { return -1 }
            return Int(bytes[(y * image.width + x) * 4])
        }
        return (image.width, image.height, levels)
    }

    private func waitForFile(_ url: URL) -> Bool {
        for _ in 0..<30 {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }
}
