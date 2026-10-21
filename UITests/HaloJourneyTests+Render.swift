// HaloJourneyTests+Render.swift: H-J21, File > Render… on SuiteUI's export
// sheet (core-loop CL-4, #1971; render-out RO-10, #429). On `-HaloSample
// keyed -HaloRenderTo <tmp>` (Bounce on live services, 48 frames at 24 fps,
// 1920 × 1080) it opens File > Render…, picks the PNG sequence format chip
// (`halo.render.format.pngSequence`) and the Half chip in Halo's options rows
// (`halo.render.size.half`), reads the summary "48 PNG files, 960 × 540, into
// a new folder "Bounce"", and presses the sheet's start button
// (`halo.render.start`, titled Export until #3402). The options rows' note
// ("Frame n of 48") is shot when it is caught: 48 half-size frames can finish
// before XCUITest looks, so then the finished line stands in for it. The
// finished line reads "Exported Bounce" with `halo.render.reveal`; the test
// then lists `<tmp>/Bounce/`: exactly `Bounce_0001.png` … `Bounce_0048.png`,
// each decoded with ImageIO at 960 × 540. Then ⌘Q and a relaunch on
// `-HaloSample reference` (300 frames of 50 keyed layers, so the movie can't
// finish before the click lands): Render…, Movie, Full, start, and
// `halo.render.cancel` as soon as the note reads "Frame n of 300"; a cancel
// leaves the run idle, so the sheet closes, and once the run has stopped
// `<tmp>` holds no `.mp4`. Texts are found by what a person reads, as H-J10
// finds its alert's text. The Model half of every step is HaloRenderJobTests
// and HaloRenderRunTests. One shot per step, `halo-render-<n>-<step>`.
import ImageIO
import XCTest

final class HaloRenderJourneyTests: XCTestCase {
    /// H-J21: a half-size PNG sequence of Bounce, then a cancelled movie of Reference.
    @MainActor func testRenderPNGSequence() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "halo-render-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }

        // 1. File > Render… on keyed; PNG Sequence, Half: the summary names 48 files at 960 × 540.
        var halo = launch(["-HaloSample", "keyed", "-HaloRenderTo", folder.path])
        openRenderSheet(halo)
        pick("halo.render.format.pngSequence", halo)
        pick("halo.render.size.half", halo)
        expectText("48 PNG files, 960 × 540, into a new folder \"Bounce\"", halo)
        halo.shot("render-1-settings")

        // 2. Start: the progress note if caught in time, then "Exported Bounce" with Reveal in Finder.
        clickStart(halo)
        let progress = progressText(of: 48, halo)
        let done = text("Exported Bounce", halo)
        XCTAssert(waitFor(seconds: 10) { progress.exists || done.exists }, "Render showed neither progress nor a result")
        if progress.exists { halo.shot("render-2-progress") }
        XCTAssert(done.waitForExistence(timeout: 60), "the render never read \"Exported Bounce\"")
        XCTAssert(halo.element("halo.render.reveal").waitForExistence(timeout: 5), "no Reveal in Finder (halo.render.reveal)")
        halo.shot("render-3-done")

        // 3. <tmp>/Bounce holds exactly Bounce_0001.png … Bounce_0048.png, each 960 × 540.
        let bounce = folder.appending(path: "Bounce", directoryHint: .isDirectory)
        let names = try FileManager.default.contentsOfDirectory(atPath: bounce.path).sorted()
        let want = (1...48).map { String(format: "Bounce_%04d.png", $0) }
        XCTAssertEqual(names, want, "the files in \(bounce.path)")
        for name in want {
            let size = pixelSize(of: bounce.appending(path: name))
            XCTAssert(size?.width == 960 && size?.height == 540, "\(name) is \(String(describing: size)), not 960 × 540")
        }
        quit(halo)

        // 4. Relaunch on reference; Render…, Movie, Full, start, Cancel once frames come in.
        halo = launch(["-HaloSample", "reference", "-HaloRenderTo", folder.path])
        openRenderSheet(halo)
        pick("halo.render.format.movie", halo)
        pick("halo.render.size.full", halo)
        halo.shot("render-4-movie-settings")
        clickStart(halo)
        let running = progressText(of: 300, halo)
        XCTAssert(running.waitForExistence(timeout: 10), "the movie's progress note never read \"Frame n of 300\"")
        XCTAssert(halo.element("halo.render.progress").exists, "no progress bar (halo.render.progress)")
        let cancel = halo.element("halo.render.cancel")
        XCTAssert(cancel.waitForExistence(timeout: 5), "no Cancel while rendering (halo.render.cancel)")
        halo.shot("render-5-movie-progress")
        cancel.click()

        // 5. Cancel leaves the run idle: the sheet closes, and no .mp4 stays in <tmp> once the run has stopped.
        let start = halo.element("halo.render.start")
        XCTAssert(waitFor(seconds: 10) { !start.exists }, "the sheet stayed open after Cancel (halo.render.start)")
        halo.shot("render-6-movie-cancelled")
        func movies() -> [String] {
            ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).filter { $0.hasSuffix(".mp4") }
        }
        // The writer removes its file when the detached run sees the cancel, a moment after the text.
        XCTAssert(waitFor(seconds: 15) { movies().isEmpty }, "a partial movie stayed: \(movies())")
    }

    // MARK: - Helpers

    @MainActor private func launch(_ arguments: [String]) -> Journey {
        let halo = Journey("Halo", self, arguments: arguments + ["-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        return halo
    }

    /// ⌘Q, as a person quits; waits for the process to end.
    @MainActor private func quit(_ halo: Journey) {
        halo.press(character: "q", .command)
        if !halo.app.wait(for: .notRunning, timeout: 15) { halo.app.terminate() }
    }

    /// File > Render…; the sheet's Format picker shows.
    @MainActor private func openRenderSheet(_ halo: Journey) {
        let file = halo.app.menuBars.firstMatch.menuBarItems["File"]
        XCTAssert(file.waitForExistence(timeout: 5), "no File menu")
        file.click()
        let item = file.menuItems["Render…"]
        XCTAssert(item.waitForExistence(timeout: 3), "the File menu has no Render…")
        XCTAssert(item.isEnabled, "File > Render… is disabled on an open composition")
        item.click()
        XCTAssert(halo.element("halo.render.format").waitForExistence(timeout: 10), "no Render sheet (halo.render.format)")
    }

    /// Clicks the chip with identifier `id` (a format chip or a size chip).
    @MainActor private func pick(_ id: String, _ halo: Journey) {
        let chip = halo.element(id)
        XCTAssert(chip.waitForExistence(timeout: 5), "no chip \(id)")
        chip.click()
    }

    /// Clicks the sheet's start button (`halo.render.start`, titled Export until #3402) once it is enabled.
    @MainActor private func clickStart(_ halo: Journey) {
        let start = halo.element("halo.render.start")
        XCTAssert(start.waitForExistence(timeout: 5), "no start button (halo.render.start)")
        XCTAssert(waitFor { start.isEnabled }, "the start button is disabled with -HaloRenderTo set")
        start.click()
    }

    /// Some text in the app reads `string` within five seconds.
    @MainActor private func expectText(_ string: String, _ halo: Journey) {
        XCTAssert(text(string, halo).waitForExistence(timeout: 5), "nothing reads \(string)")
    }

    /// The first element whose label is `string`, or a static text whose
    /// value is: SwiftUI's Text reads as either.
    @MainActor private func text(_ string: String, _ halo: Journey) -> XCUIElement {
        let staticText = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let predicate = NSPredicate(format: "label == %@ OR (elementType == %@ AND value == %@)", string, staticText, string)
        return halo.app.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// The progress note's "Frame n of `total`", read from a static text's label or value.
    @MainActor private func progressText(of total: Int, _ halo: Journey) -> XCUIElement {
        let tail = " of \(total)"
        let predicate = NSPredicate(
            format: "(label BEGINSWITH 'Frame ' AND label ENDSWITH %@) OR (value BEGINSWITH 'Frame ' AND value ENDSWITH %@)",
            tail, tail)
        return halo.app.staticTexts.matching(predicate).firstMatch
    }

    /// The pixel size of the PNG at `url`, decoded with ImageIO; nil when it doesn't decode.
    private func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        return (image.width, image.height)
    }

    /// Whether `condition` holds within `seconds`.
    @MainActor private func waitFor(seconds: Int = 3, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 5) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
