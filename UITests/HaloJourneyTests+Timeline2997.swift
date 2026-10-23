// HaloJourneyTests+Timeline2997.swift: HJ-FR (frame-rates FR-8b, slice FR-halo), a 29.97 fps composition
// from start to render. New Composition…, the Frame Rate menu's "29.97 fps" (one of its nine rates),
// Duration 10, Create: the inspector header reads "29.97 fps · 10 s". Animation > Go to End puts the
// playhead on frame 299, whose drop-frame timecode is "00:00:09;29": the timeline's 300 frames end at
// 00:00:10;00 (HaloFrameRateTests counts that). File > Render…, PNG Sequence, Half, start: the render
// folder (`-HaloRenderTo`) fills with exactly 300 PNGs. The Model half is HaloFrameRateTests and
// HaloFrameRateCommandTests. One shot per step, `halo-rates-<n>-<step>`.
import XCTest

extension HaloTimelineJourneyTests {
    /// New Composition at 29.97 fps for 10 s; the last frame reads 00:00:09;29; the render writes 300 frames.
    @MainActor func testCompositionAt2997() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "halo-2997-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let halo = Journey("Halo", self, arguments: ["-HaloRenderTo", folder.path, "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. New Composition…: pick 29.97 fps from the Frame Rate menu, Duration 10.
        halo.reachable("New Composition…").click()
        let sheet = halo.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 5), "New Composition… opened no sheet")
        var menu = sheet.menuButtons["Frame Rate"]
        if !menu.waitForExistence(timeout: 5) { menu = sheet.popUpButtons["Frame Rate"] }
        XCTAssert(menu.waitForExistence(timeout: 5), "the sheet has no Frame Rate menu")
        menu.click()
        let ntsc = halo.app.menuItems["29.97 fps"]
        XCTAssert(ntsc.waitForExistence(timeout: 5), "the Frame Rate menu offers no 29.97 fps")
        XCTAssert(halo.app.menuItems["23.976 fps"].exists && halo.app.menuItems["59.94 fps"].exists, "the menu lacks the NTSC rates")
        halo.shot("rates-1-menu")
        ntsc.click()
        let duration = sheet.textFields["Duration (seconds)"]
        XCTAssert(duration.waitForExistence(timeout: 5), "no Duration (seconds) field")
        duration.click()
        duration.typeKey("a", modifierFlags: .command)
        duration.typeText("10")
        halo.shot("rates-2-sheet")
        halo.reachable("Create", in: sheet).click()

        // 2. The header names the exact rate; Go to End lands on frame 299 at 00:00:09;29.
        let header = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", "29.97 fps · 10 s")).firstMatch
        XCTAssert(header.waitForExistence(timeout: 5), "the header doesn't read 29.97 fps · 10 s")
        halo.choose(menu: ["Animation", "Go to End"])
        XCTAssert(readsText("00:00:09;29 · frame 299", halo).waitForExistence(timeout: 5),
                  "Go to End doesn't read 00:00:09;29 · frame 299 (300 frames ending at 00:00:10;00)")
        halo.shot("rates-3-end")

        // 3. Render a half-size PNG sequence: exactly 300 frames.
        halo.choose(menu: ["File", "Render…"])
        for id in ["halo.render.format.pngSequence", "halo.render.size.half", "halo.render.start"] {
            let control = halo.element(id)
            XCTAssert(control.waitForExistence(timeout: 5), "no \(id)")
            if id == "halo.render.start" { XCTAssert(poll(5) { control.isEnabled }, "the start button is disabled") }
            control.click()
        }
        XCTAssert(poll(240) { self.pngs(in: folder) == 300 }, "the render wrote \(pngs(in: folder)) PNGs, not 300")
        halo.shot("rates-4-rendered")
    }

    /// The PNG files anywhere under `folder`.
    private func pngs(in folder: URL) -> Int {
        let files = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: nil)?.allObjects ?? []
        return files.compactMap { $0 as? URL }.filter { $0.pathExtension == "png" }.count
    }

    /// The first element whose label starts with `string`, or a static text whose value does.
    @MainActor private func readsText(_ string: String, _ halo: Journey) -> XCUIElement {
        let staticText = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let predicate = NSPredicate(
            format: "label BEGINSWITH %@ OR (elementType == %@ AND value BEGINSWITH %@)", string, staticText, string)
        return halo.app.windows.firstMatch.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Whether `condition` holds within `seconds`.
    @MainActor private func poll(_ seconds: Int, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 5) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
