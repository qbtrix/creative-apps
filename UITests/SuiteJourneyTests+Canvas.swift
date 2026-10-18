// SuiteJourneyTests+Canvas.swift: SJ9, SJ10 and SJ26 (canvas-marks packet,
// CM-12), on the gallery's `canvas`, `canvas-pt`, `marks`, `surface` and
// `surface-empty` pages (Sources/SuiteUI/Gallery/GalleryCanvas.swift). Every
// change is read from the `suite.gallery.log` element, one line per change;
// points on the canvas are placed from `suite.canvas.artboard`'s frame, so a
// document point times the zoom is a view point from the artboard's corner.
//
// SJ9 drags first: the canvas takes keys only once a drag has focused it.
// Then ⌘= twice reads "200 %" on the pill (the proof the page, not a menu,
// took ⌘=), a third ⌘= makes the document wider than the viewport so → has
// room to scroll a tenth of it, a Space-drag pans without a drag line, and
// ⌘0 fits back to 100 %. Under -SuiteGalleryFakes the fake navigator
// doubles (400 %). `canvas-pt`'s ruler corner reads "pt".
// SJ10's zoom chip toggles 100 % and 400 % only, so 25 % isn't walked. At
// 400 % the marks viewport can't be scrolled by key and the bottom-right
// handle lies past its edge, so the top-left handle and rotate zone stand in.
// SJ26 sizes the window to 880 × 700 and 1440 × 900; the sizer fits a size
// to the display, so on the 1024 × 768 runner the second reads about 1024.
import CoreGraphics
import XCTest

extension SuiteJourneyTests {
    /// SJ9: ⌘= steps the live zooms, ⌘0 fits, a tool drag logs in document pixels, Space-drag and → scroll.
    @MainActor func testCanvasZoomPanAndDrag() throws {
        let gallery = canvasJourneyOpen("canvas")
        let log = gallery.element("suite.gallery.log")
        let pill = canvasJourneyElement("suite.gallery.canvas.zoom", gallery)
        XCTAssertEqual(pill.label, "100 %", "the pill doesn't open at 100 %")
        XCTAssertEqual(canvasJourneyElement("suite.canvas.rulerUnit", gallery).label, "px", "canvas's ruler unit")
        // 1. A 100 pt drag from the artboard's corner, at 100 %: one drag, in document pixels.
        canvasJourneyDrag(gallery, from: .zero, by: CGVector(dx: 100, dy: 0))
        // The artboard's corner can sit on a half point, so each pixel may round one either way.
        XCTAssert(canvasJourneyWait { self.canvasJourneyLines(log).last?.hasPrefix("drag ") == true }, "the drag logged nothing")
        let drag = canvasJourneyNumbers(canvasJourneyLines(log).last ?? "")
        XCTAssert(drag.count == 5 && zip(drag, [0, 0, 100, 0]).allSatisfy { abs($0 - $1) <= 1 } && drag.last == 1,
                  "the drag logged \(canvasJourneyLines(log).last ?? "nothing"), not drag (0,0)→(100,0) ends 1")
        gallery.shot("canvas-dragged")
        // 2. ⌘= twice walks 1.5 and 2.
        gallery.press(character: "=", .command)
        gallery.press(character: "=", .command)
        XCTAssert(canvasJourneyWait { pill.label == "200 %" }, "⌘= twice reads \(pill.label), not 200 %")
        canvasJourneyExpectLast("zoom 2", log)
        gallery.shot("canvas-zoom-200")
        // 3. At 300 % the document (1264 pt with its margins) is wider than the viewport.
        gallery.press(character: "=", .command)
        XCTAssert(canvasJourneyWait { pill.label == "300 %" }, "a third ⌘= reads \(pill.label), not 300 %")
        let corner = canvasJourneyElement("suite.canvas.rulerUnit", gallery).frame
        let page = gallery.element("suite.gallery.canvas").frame
        let tenth = (page.maxX - 12 - corner.maxX) / 10
        // 4. → scrolls a tenth of the viewport: the artboard moves left by that much.
        let artboard = canvasJourneyElement("suite.canvas.artboard", gallery)
        let beforeKey = artboard.frame.minX
        gallery.press(.rightArrow)
        XCTAssert(canvasJourneyWait { abs(beforeKey - artboard.frame.minX - tenth) <= max(3, tenth * 0.1) },
                  "→ moved the artboard \(beforeKey - artboard.frame.minX) pt, not a tenth of the viewport (\(tenth))")
        gallery.shot("canvas-arrow-scrolled")
        // 5. A Space-drag 80 pt right pans the content with the pointer (back toward
        // the → scroll, so it has room wherever the zoom left the scroll) and logs no drag.
        let linesBefore = canvasJourneyLines(log)
        if CGPreflightPostEventAccess() {
            let beforePan = artboard.frame.minX
            canvasJourneyHoldSpace {
                canvasJourneyDrag(gallery, from: CGPoint(x: 600, y: 300), by: CGVector(dx: 80, dy: 0))
            }
            XCTAssert(canvasJourneyWait { abs(artboard.frame.minX - beforePan - 80) <= 3 },
                      "an 80 pt Space-drag moved the artboard \(artboard.frame.minX - beforePan) pt")
            XCTAssertEqual(canvasJourneyLines(log), linesBefore, "the Space-drag logged a line")
            gallery.shot("canvas-space-panned")
        }
        // 6. ⌘0 fits the 400 x 300 document: 100 %.
        gallery.press(character: "0", .command)
        XCTAssert(canvasJourneyWait { pill.label == "100 %" }, "⌘0 reads \(pill.label), not 100 %")
        canvasJourneyExpectLast("zoom 1", log)
        gallery.app.terminate()

        // 7. The fake navigator doubles: 2, then 4.
        let faked = canvasJourneyOpen("canvas", "-SuiteGalleryFakes")
        let fakedPill = canvasJourneyElement("suite.gallery.canvas.zoom", faked)
        canvasJourneyDrag(faked, from: CGPoint(x: 20, y: 20), by: CGVector(dx: 10, dy: 10))
        faked.press(character: "=", .command)
        faked.press(character: "=", .command)
        XCTAssert(canvasJourneyWait { fakedPill.label == "400 %" }, "the fake's ⌘= twice reads \(fakedPill.label)")
        canvasJourneyExpectLast("zoom 4", faked.element("suite.gallery.log"))
        faked.shot("canvas-fake-400")
        faked.app.terminate()

        // 8. canvas-pt's ruler corner names its unit.
        let points = canvasJourneyOpen("canvas-pt")
        XCTAssertEqual(canvasJourneyElement("suite.canvas.rulerUnit", points).label, "pt", "canvas-pt's ruler unit")
        points.shot("canvas-pt-ruler")
        if !CGPreflightPostEventAccess() {
            throw XCTSkip("step 5, the Space-drag: the runner can't post a held Space (CGPreflightPostEventAccess is false)")
        }
    }

    /// SJ10: every handle hits at least 12 × 12 pt; a corner resizes, ⇧ keeps the aspect, a rotate zone turns, at 100 % and 400 %.
    @MainActor func testSelectionHandlesAtEveryZoom() throws {
        let gallery = canvasJourneyOpen("marks")
        let log = gallery.element("suite.gallery.log")
        canvasJourneyExpectHits(log, zoom: 1)
        // At 100 %: the bottom-right handle of (60,60) 160 × 120 is at (220,180).
        canvasJourneyDrag(gallery, from: CGPoint(x: 220, y: 180), by: CGVector(dx: 50, dy: 50))
        XCTAssert(canvasJourneyWait { self.canvasJourneyLines(log).contains("handle bottomRight") }, "no handle bottomRight")
        canvasJourneyExpectRect(log, near: [60, 60, 210, 170])
        gallery.shot("marks-100-resized")
        canvasJourneyDrag(gallery, from: CGPoint(x: 270, y: 230), by: CGVector(dx: 40, dy: 0), shift: true)
        canvasJourneyExpectLast("keepAspect", log, within: 3)
        canvasJourneyExpectAspect(log, 210.0 / 170.0)
        canvasJourneyResetSelection(gallery, log)
        // The bottom-right rotate zone's centre is 14 pt out from the corner; a quarter turn about the box's centre.
        canvasJourneyTurn(gallery, at: CGPoint(x: 234, y: 194), about: CGPoint(x: 140, y: 120))
        canvasJourneyExpectRotate(log)
        gallery.shot("marks-100-rotated")
        canvasJourneyResetSelection(gallery, log)

        // At 400 %: the top-left handle of the reset box is at (240,240).
        canvasJourneyElement("suite.gallery.marks.zoom", gallery).click()
        canvasJourneyExpectHits(log, zoom: 4)
        gallery.shot("marks-400-open")
        canvasJourneyDrag(gallery, from: CGPoint(x: 240, y: 240), by: CGVector(dx: -40, dy: -40))
        XCTAssert(canvasJourneyWait { self.canvasJourneyLines(log).contains("handle topLeft") }, "no handle topLeft at 400 %")
        canvasJourneyExpectRect(log, near: [50, 50, 170, 130])
        canvasJourneyDrag(gallery, from: CGPoint(x: 200, y: 200), by: CGVector(dx: -40, dy: 0), shift: true)
        canvasJourneyExpectLast("keepAspect", log, within: 3)
        canvasJourneyExpectAspect(log, 170.0 / 130.0)
        canvasJourneyResetSelection(gallery, log)
        canvasJourneyTurn(gallery, at: CGPoint(x: 226, y: 226), about: CGPoint(x: 560, y: 480))
        canvasJourneyExpectRotate(log)
        gallery.shot("marks-400-rotated")
    }

    /// SJ26: the surface's artboard keeps its aspect, stays 64 pt clear and centred at two window sizes; a 0 × 0 one draws 1 × 1.
    @MainActor func testCanvasSurfaceCentersArtboard() throws {
        for size in ["880x700", "1440x900"] {
            let gallery = canvasJourneyOpen("surface", "-SuiteWindowSize", size)
            let log = gallery.element("suite.gallery.log")
            XCTAssert(canvasJourneyWait { self.canvasJourneyLines(log).last?.hasPrefix("artboard ") == true }, "no artboard line at \(size)")
            let numbers = canvasJourneyNumbers(canvasJourneyLines(log).last ?? "")
            XCTAssertEqual(numbers.count, 4, "the artboard line at \(size) reads \(canvasJourneyLines(log).last ?? "nothing")")
            guard numbers.count == 4, numbers[1] > 0 else { gallery.app.terminate(); continue }
            let (width, height, x, y) = (Double(numbers[0]), Double(numbers[1]), Double(numbers[2]), Double(numbers[3]))
            XCTAssertGreaterThanOrEqual(x, 63, "the artboard sits \(x) pt from the surface's left at \(size)")
            XCTAssertGreaterThanOrEqual(y, 63, "the artboard sits \(y) pt from the surface's top at \(size)")
            XCTAssertEqual(width / height, 4.0 / 3.0, accuracy: 4.0 / 300, "the artboard's aspect at \(size)")
            let artboard = canvasJourneyElement("suite.canvas.artboard", gallery).frame
            let page = gallery.element("suite.gallery.surface").frame
            XCTAssertEqual(artboard.width, width, accuracy: 1, "the artboard's drawn width at \(size)")
            XCTAssertEqual(artboard.height, height, accuracy: 1, "the artboard's drawn height at \(size)")
            XCTAssertEqual(artboard.midX, page.midX, accuracy: 1, "the artboard isn't centred across the page at \(size)")
            let surface = CGRect(x: artboard.minX - x, y: artboard.minY - y, width: 2 * x + width, height: 2 * y + height)
            XCTAssert(page.insetBy(dx: -1, dy: -1).contains(surface), "the surface \(surface) spills out of the page \(page) at \(size)")
            let window = gallery.app.windows.firstMatch.frame
            gallery.shot("surface-\(Int(window.width))x\(Int(window.height))")
            gallery.app.terminate()
        }
        let empty = canvasJourneyOpen("surface-empty")
        let log = empty.element("suite.gallery.log")
        XCTAssert(canvasJourneyWait { self.canvasJourneyLines(log).last?.hasPrefix("artboard 1×1 at ") == true },
                  "a 0 x 0 artboard logs \(canvasJourneyLines(log).last ?? "nothing"), not 1×1")
        let board = empty.element("suite.canvas.artboard")
        if board.waitForExistence(timeout: 5) {
            XCTAssertLessThanOrEqual(max(board.frame.width, board.frame.height), 1.5, "a 0 x 0 artboard draws \(board.frame.size)")
        }
        empty.shot("surface-empty-artboard")
    }

    /// Launches the gallery on `page` with `extra` arguments, and waits for its root.
    @MainActor private func canvasJourneyOpen(_ page: String, _ extra: String...) -> Journey {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", page] + extra)
        XCTAssert(gallery.element("suite.gallery.\(page)").waitForExistence(timeout: 30), "no gallery page \(page)")
        return gallery
    }

    /// The element `id`, failing when it doesn't come within five seconds.
    @MainActor private func canvasJourneyElement(_ id: String, _ gallery: Journey) -> XCUIElement {
        let element = gallery.element(id)
        XCTAssert(element.waitForExistence(timeout: 5), "no \(id) on the page")
        return element
    }

    /// The screen point `point` view points from the artboard's top left.
    @MainActor private func canvasJourneyPoint(_ gallery: Journey, _ point: CGPoint) -> XCUICoordinate {
        let window = gallery.app.windows.firstMatch
        let artboard = canvasJourneyElement("suite.canvas.artboard", gallery).frame
        return window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
            dx: artboard.minX - window.frame.minX + point.x, dy: artboard.minY - window.frame.minY + point.y))
    }

    /// Presses at `point` (from the artboard's corner) and drags `offset`, with ⇧ held when `shift`.
    @MainActor private func canvasJourneyDrag(_ gallery: Journey, from point: CGPoint, by offset: CGVector, shift: Bool = false) {
        let start = canvasJourneyPoint(gallery, point)
        let drag = { start.press(forDuration: 0.1, thenDragTo: start.withOffset(offset)) }
        if shift { XCUIElement.perform(withKeyModifiers: .shift) { drag() } } else { drag() }
    }

    /// Drags from `start` a quarter turn clockwise about `centre`, both from the artboard's corner.
    @MainActor private func canvasJourneyTurn(_ gallery: Journey, at start: CGPoint, about centre: CGPoint) {
        let v = CGVector(dx: start.x - centre.x, dy: start.y - centre.y)
        let end = CGPoint(x: centre.x - v.dy, y: centre.y + v.dx)
        canvasJourneyDrag(gallery, from: start, by: CGVector(dx: end.x - start.x, dy: end.y - start.y))
    }

    /// The selection chip off, then on: the box is (60,60) 160 × 120 again.
    @MainActor private func canvasJourneyResetSelection(_ gallery: Journey, _ log: XCUIElement) {
        let chip = canvasJourneyElement("suite.gallery.marks.selection", gallery)
        chip.click()
        canvasJourneyExpectLast("handles none", log, within: 3)
        chip.click()
        canvasJourneyExpectLast("hits 12 min 12×12", log, within: 3)
    }

    /// The marks page's readouts at `zoom`: at least eight handle hit frames, none under 12 × 12 pt.
    @MainActor private func canvasJourneyExpectHits(_ log: XCUIElement, zoom: Int) {
        canvasJourneyExpectLast("point", log, within: 3, prefix: true)
        let lines = canvasJourneyLines(log)
        XCTAssert(lines.suffix(3).contains { $0.hasSuffix("zoom \(zoom)") }, "no point line at zoom \(zoom): \(lines.suffix(3))")
        let hits = canvasJourneyNumbers(lines.last { $0.hasPrefix("hits ") } ?? "")
        XCTAssertEqual(hits.count, 3, "no hits line at zoom \(zoom): \(lines.suffix(3))")
        guard hits.count == 3 else { return }
        XCTAssertGreaterThanOrEqual(hits[0], 8, "only \(hits[0]) handle hit frames at zoom \(zoom)")
        XCTAssertGreaterThanOrEqual(min(hits[1], hits[2]), 12, "a hit frame is \(hits[1])×\(hits[2]) pt at zoom \(zoom)")
    }

    /// The newest `rect (x,y) W×H ends n` line comes, each number within 2 px of `expected`.
    @MainActor private func canvasJourneyExpectRect(_ log: XCUIElement, near expected: [Int]) {
        let near = { (rect: [Int]) in rect.count >= 4 && zip(rect, expected).allSatisfy { abs($0 - $1) <= 2 } }
        XCTAssert(canvasJourneyWait { near(self.canvasJourneyRect(log) ?? []) },
                  "the box ended at \(canvasJourneyRect(log)?.prefix(4) ?? []), not about \(expected)")
    }

    /// The newest box keeps width / height `aspect` within a pixel.
    @MainActor private func canvasJourneyExpectAspect(_ log: XCUIElement, _ aspect: Double) {
        // A rect line after the newest keepAspect: the ⇧ drag's own end.
        let after = { self.canvasJourneyLines(log).reversed().prefix { $0 != "keepAspect" }.first { $0.hasPrefix("rect ") } }
        XCTAssert(canvasJourneyWait { after() != nil }, "the ⇧ drag logged no rect: \(canvasJourneyLines(log).suffix(3))")
        let rect = canvasJourneyNumbers(after() ?? "")
        guard rect.count >= 4 else { return XCTFail("the ⇧ drag's rect reads \(rect)") }
        XCTAssertEqual(Double(rect[3]), Double(rect[2]) / aspect, accuracy: 1.5, "⇧ didn't keep the aspect: \(rect.prefix(4))")
    }

    /// The newest line is `rotate 90 ends n`, within a degree.
    @MainActor private func canvasJourneyExpectRotate(_ log: XCUIElement) {
        let newest = { self.canvasJourneyLines(log).suffix(2).last { $0.hasPrefix("rotate ") } }
        XCTAssert(canvasJourneyWait { newest() != nil }, "the rotate zone drag logged \(canvasJourneyLines(log).suffix(2))")
        let turned = canvasJourneyNumbers(newest() ?? "").first ?? 0
        XCTAssertLessThanOrEqual(abs(turned - 90), 1, "a quarter turn logged rotate \(turned)")
    }

    /// The numbers of the newest `rect` line, or nil when there is none.
    @MainActor private func canvasJourneyRect(_ log: XCUIElement) -> [Int]? {
        canvasJourneyLines(log).last { $0.hasPrefix("rect ") }.map(canvasJourneyNumbers)
    }

    /// The whole numbers in `line`, in order: "rect (60,60) 210×170 ends 1" is [60, 60, 210, 170, 1].
    private func canvasJourneyNumbers(_ line: String) -> [Int] {
        line.split { !$0.isNumber && $0 != "-" }.compactMap { Int($0) }
    }

    /// One of the newest `within` lines is `line` (or starts with it when `prefix`).
    @MainActor private func canvasJourneyExpectLast(_ line: String, _ log: XCUIElement, within: Int = 1, prefix: Bool = false) {
        let matches = { (entry: String) in prefix ? entry.hasPrefix(line) : entry == line }
        XCTAssert(canvasJourneyWait { self.canvasJourneyLines(log).suffix(within).contains(where: matches) },
                  "the log's newest lines read \(canvasJourneyLines(log).suffix(within)), not \(line)")
    }

    /// The log's lines: its value when it has one, else its label.
    @MainActor private func canvasJourneyLines(_ log: XCUIElement) -> [String] {
        let value = log.value as? String ?? ""
        return (value.isEmpty ? log.label : value).split(separator: "\n").map(String.init)
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func canvasJourneyWait(_ condition: () -> Bool) -> Bool {
        (0..<15).contains { _ in condition() || { Thread.sleep(forTimeInterval: 0.2); return false }() } || condition()
    }

    /// Runs `body` with Space held down, posted as CGEvents (virtual key 49).
    @MainActor private func canvasJourneyHoldSpace(_ body: () -> Void) {
        CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
        body()
        CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: false)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
    }
}
