// SuiteJourneyTests+ListMenus.swift: SJ22 and SP4, LL-15 (lists-and-layers
// packet, Journey steps 4 and 5). SJ22 right-clicks Ball's row in the `window`
// page's sidebar: Duplicate logs `menu duplicate ball`, and Delete is disabled
// with GalleryLists.deleteHelp as its help tag (#73). A help tag can reach
// accessibility with no text (dev run 38835566584, Photo's PJ-7), so its text
// is read from its pixels with Vision when accessibility gives none. SP4
// scrolls `layers-300` (`suite.layers`, rows `suite.layers.row.<id>`) and
// `grid-2000` (cells `suite.grid.<id>`) end to end and back under
// -SuitePerfProbe; series `layers-scroll` and `grid-scroll` each need 60 or
// more frame intervals (QB-S7, report-only: `perf()` attaches the p95 against
// SuiteJourneyTests.listScroll, which has no gate yet).
import CoreGraphics
import ImageIO
import Vision
import XCTest

extension SuiteJourneyTests {
    /// The text the window page's Delete carries (GalleryLists.deleteHelp).
    private static let listDeleteHelp = "The gallery keeps every layer, so Delete is unavailable here."

    /// SJ22: a sidebar row's context menu runs Duplicate and shows Delete disabled with its reason.
    @MainActor func testRowContextMenus() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "window"])
        XCTAssert(gallery.element("suite.gallery.window").waitForExistence(timeout: 30), "no window page")
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log on the window page")
        let ball = gallery.element("suite.sidebar").staticTexts["Ball"].firstMatch
        XCTAssert(ball.waitForExistence(timeout: 10), "the sidebar has no Ball row")

        // 1. Right-click Ball, choose Duplicate.
        ball.listMiddle.rightClick()
        let duplicate = gallery.app.menuItems["Duplicate"]
        XCTAssert(duplicate.waitForExistence(timeout: 5), "Ball's context menu has no Duplicate")
        gallery.shot("window-row-menu")
        duplicate.click()
        XCTAssert(menusWait { self.menusLastLine(log) == "menu duplicate ball" },
                  "the log's last line reads \(menusLastLine(log)), not menu duplicate ball")

        // 2. Right-click Ball again: Delete is there, disabled, and its help tag says why.
        ball.listMiddle.rightClick()
        let delete = gallery.app.menuItems["Delete"]
        XCTAssert(delete.waitForExistence(timeout: 5), "Ball's context menu has no Delete")
        XCTAssertFalse(delete.isEnabled, "Ball's Delete is enabled")
        delete.hover()
        let tags = gallery.app.helpTags
        XCTAssert(tags.firstMatch.waitForExistence(timeout: 5), "hovering Delete showed no help tag")
        var read: [String] = []
        let said = menusWait {
            read = tags.allElementsBoundByIndex.map { self.menusHelpText($0) }
            return read.contains { Self.menusSays($0, Self.listDeleteHelp) }
        }
        if !said, tags.firstMatch.exists {
            let attachment = XCTAttachment(screenshot: tags.firstMatch.screenshot())
            attachment.name = "window-delete-help-tag"
            add(attachment)
        }
        XCTAssert(said, "Delete doesn't say \(Self.listDeleteHelp); its help tag reads \(read)")
        gallery.shot("window-row-menu-delete")
        gallery.press(.escape)
        XCTAssert(menusWait { !delete.exists }, "the context menu stayed open after Escape")
    }

    /// SP4: `layers-300` and `grid-2000` scroll end to end and back; each series holds 60 or more intervals.
    @MainActor func testListAndGridScroll() throws {
        let layers = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "layers-300", "-SuitePerfProbe"])
        let list = layers.element("suite.layers")
        XCTAssert(list.waitForExistence(timeout: 30), "layers-300 has no list (suite.layers)")
        // Rows run front to back; which end shows first is read, not assumed.
        let ends = ["group-10", "layer-1-1"].map { layers.element("suite.layers.row.\($0)") }
        let topFirst = ends[0].listShows(in: list)
        menusScroll(list, until: topFirst ? ends[1] : ends[0], by: -300)
        layers.shot("layers-300-end")
        menusScroll(list, until: topFirst ? ends[0] : ends[1], by: 300)
        if let document = layers.perf() { menusExpectIntervals(document, series: "layers-scroll") }
        layers.app.terminate()

        let grid = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "grid-2000", "-SuitePerfProbe"])
        let page = grid.element("suite.gallery.grid-2000")
        XCTAssert(page.waitForExistence(timeout: 30), "no grid-2000 page")
        XCTAssert(grid.element("suite.grid.1").waitForExistence(timeout: 10), "grid-2000 shows no first cell (suite.grid.1)")
        menusScroll(page, until: grid.element("suite.grid.2000"), by: -600)
        grid.shot("grid-2000-end")
        menusScroll(page, until: grid.element("suite.grid.1"), by: 600)
        if let document = grid.perf() { menusExpectIntervals(document, series: "grid-scroll") }
    }

    /// Scrolls the middle of `area` by `delta` pixels until `target` is hittable, at most 300 times.
    @MainActor private func menusScroll(_ area: XCUIElement, until target: XCUIElement, by delta: CGFloat) {
        var scrolls = 0
        while !target.listShows(in: area), scrolls < 300 {
            area.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).scroll(byDeltaX: 0, deltaY: delta)
            scrolls += 1
        }
        XCTAssert(target.listShows(in: area), "\(scrolls) scrolls didn't bring the \(delta < 0 ? "far" : "near") end into view")
    }

    /// Fails when `series` has fewer than 60 frame intervals in `document`: its numbers mean nothing.
    @MainActor private func menusExpectIntervals(_ document: ProbeDocument, series: String) {
        let count = document.intervals[series]?.count ?? 0
        XCTAssert(
            count >= Journey.minimumSamples,
            "series \(series) has \(count) intervals, under \(Journey.minimumSamples): its numbers mean nothing")
    }

    /// The last line of what an element reads: its value when it has one, else its label.
    @MainActor private func menusLastLine(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return (value.isEmpty ? element.label : value).split(separator: "\n").last.map(String.init) ?? ""
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func menusWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    /// A help tag's text: its label, title and value, or, when all are empty, what Vision reads in a shot of it.
    @MainActor private func menusHelpText(_ tag: XCUIElement) -> String {
        guard tag.exists else { return "" }
        let named = [tag.label, tag.title, (tag.value as? String) ?? ""].filter { !$0.isEmpty }
        if !named.isEmpty { return named.joined(separator: " ") }
        return Self.menusRecognized(tag.screenshot().pngRepresentation)
    }

    /// Whether `text` holds `expected`, ignoring case, punctuation and spacing.
    private static func menusSays(_ text: String, _ expected: String) -> Bool {
        func letters(_ string: String) -> String {
            String(string.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) })
        }
        let wanted = letters(expected)
        return !wanted.isEmpty && letters(text).contains(wanted)
    }

    /// The lines Vision finds in a PNG, joined by spaces; drawn three times larger first, as a tag's type is small.
    private static func menusRecognized(_ png: Data) -> String {
        guard let source = CGImageSourceCreateWithData(png as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB), image.width > 0, image.height > 0,
            let context = CGContext(
                data: nil, width: image.width * 3, height: image.height * 3, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return "" }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width * 3, height: image.height * 3))
        guard let large = context.makeImage() else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        guard (try? VNImageRequestHandler(cgImage: large, options: [:]).perform([request])) != nil else { return "" }
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
    }
}
