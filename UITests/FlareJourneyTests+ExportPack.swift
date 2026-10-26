// FlareJourneyTests+ExportPack.swift: FJ-X1 of export-pack (FV-6, turned on live by FV-7;
// docs/blueprints/flare/features/export-pack.md, Journey steps), on `-FlareSample bounce` (550 × 400, 24 fps,
// 48 frames, scene `scene-1`) with `-FlareExportTo` on this test's own temp folder, so Export writes with no panel.
// File > Export… shows the MP4 and GIF chips; GIF with Loop forever writes scene-1.gif, 48 frames that loop
// forever; MP4 writes scene-1.mp4 (an `ftyp` box); Cancel on a running MP4 leaves no file. One shot per step,
// `flare-export-pack-<step>`. Skipped until FV-7 puts it on the live services.
import ImageIO
import XCTest

final class FlareExportPackJourneyTests: XCTestCase {
    /// FV-7 turns this on once the run writes on the live services.
    private static let live = false

    @MainActor func testExportLoopAsGIFAndMP4() throws {
        guard Self.live else { throw XCTSkip("waits on FV-7") }
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-export-pack-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce", "-FlareExportTo", folder.path])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. File > Export…: the MP4 and GIF chips.
        let start = openSheet(flare)
        for id in ["flare.export.format.mp4", "flare.export.format.gif"] {
            XCTAssert(flare.element(id).waitForExistence(timeout: 5), "the sheet has no \(id)")
        }
        flare.shot("export-pack-1-sheet")

        // 2. GIF, Loop forever on: scene-1.gif, 48 frames, loop count 0.
        flare.element("flare.export.format.gif").click()
        let loop = flare.element("flare.export.loop")
        XCTAssert(loop.waitForExistence(timeout: 5), "GIF shows no Loop forever (flare.export.loop)")
        XCTAssert(flare.element("flare.export.fps").exists, "GIF shows no Frame rate (flare.export.fps)")
        start.click()
        let gif = folder.appending(path: "scene-1.gif")
        XCTAssert(Self.waitFor { FileManager.default.fileExists(atPath: gif.path) }, "Export wrote no scene-1.gif")
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(gif as CFURL, nil), "scene-1.gif isn't an image")
        XCTAssertEqual(CGImageSourceGetCount(source), 48, "scene-1.gif isn't 48 frames")
        let properties = CGImageSourceCopyProperties(source, nil) as? [CFString: Any]
        let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        XCTAssertEqual((gifProperties?[kCGImagePropertyGIFLoopCount] as? NSNumber)?.intValue, 0, "the GIF doesn't loop forever")
        flare.shot("export-pack-2-gif")

        // 3. Done; File > Export…; MP4: scene-1.mp4 with an ftyp box.
        close(flare)
        let mp4Start = openSheet(flare)
        flare.element("flare.export.format.mp4").click()
        XCTAssertFalse(flare.element("flare.export.loop").exists, "MP4 shows Loop forever")
        mp4Start.click()
        let mp4 = folder.appending(path: "scene-1.mp4")
        XCTAssert(Self.waitFor { FileManager.default.fileExists(atPath: mp4.path) }, "Export wrote no scene-1.mp4")
        let head = (try? Data(contentsOf: mp4)).map { [UInt8]($0.prefix(8)) } ?? []
        XCTAssertEqual(Array(head.suffix(4)), Array("ftyp".utf8), "scene-1.mp4 has no ftyp box")
        flare.shot("export-pack-3-mp4")

        // 4. Done; the MP4 file moved away; Export then Cancel at once: no scene-1.mp4 is left.
        close(flare)
        try FileManager.default.removeItem(at: mp4)
        let again = openSheet(flare)
        flare.element("flare.export.format.mp4").click()
        again.click()
        let cancel = flare.element("flare.export.cancel")
        XCTAssert(cancel.waitForExistence(timeout: 5), "the running sheet has no Cancel (flare.export.cancel)")
        cancel.click()
        XCTAssert(flare.app.sheets.firstMatch.waitForNonExistence(timeout: 10), "Cancel left the sheet open")
        XCTAssertFalse(FileManager.default.fileExists(atPath: mp4.path), "a cancelled MP4 left scene-1.mp4")
        flare.shot("export-pack-4-cancelled")
    }

    // MARK: - Helpers

    /// File > Export…; returns the sheet's Export button.
    @MainActor private func openSheet(_ flare: Journey) -> XCUIElement {
        flare.app.menuBars.firstMatch.menuBarItems["File"].click()
        let item = flare.app.menuBars.firstMatch.menuItems["Export…"]
        XCTAssert(item.waitForExistence(timeout: 5) && item.isEnabled, "File > Export… is missing or disabled")
        item.click()
        XCTAssert(flare.app.sheets.firstMatch.waitForExistence(timeout: 10), "Export… showed no sheet")
        let start = flare.element("flare.export.start")
        XCTAssert(start.waitForExistence(timeout: 5), "the sheet has no Export (flare.export.start)")
        return start
    }

    /// Done once the run finished; the sheet goes.
    @MainActor private func close(_ flare: Journey) {
        let done = flare.element("flare.export.dismiss")
        XCTAssert(Self.waitFor { done.exists }, "the run never finished (no Done)")
        done.click()
        XCTAssert(flare.app.sheets.firstMatch.waitForNonExistence(timeout: 5), "Done left the sheet open")
    }

    private static func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<300 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}
