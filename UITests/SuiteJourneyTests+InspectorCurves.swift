// SuiteJourneyTests+InspectorCurves.swift: SJ16, SJ20, SJ24 and the
// inspector's report-only latency tests, IC-14 (packet
// docs/blueprints/suiteui/features/inspector-controls.md). The pages are
// `curves` and `inspector` (Sources/SuiteUI/Gallery/GalleryInspector.swift),
// whose `suite.gallery.log` writes one line per change and `<what> ends <n>`
// per gesture end, n counting every end so far.
// SJ16, on the ToneCurveEditor `suite.gallery.curves.tone` (points (0,0),
// (0.5,0.5), (1,1)): a click on an empty spot adds a point, a drag moves it,
// ↑ nudges the focused point 0.01, Tab moves focus to the next point, a
// middle point dragged out of the well goes, Delete removes the focused
// middle point, and Delete on an end does nothing. Each gesture is one end.
// SJ20, on the CurveEditor `suite.gallery.curves.easing` (handles (0.42, 0)
// and (0.58, 1)): a drag of handle 1, then Tab, ↑ and ⇧↑ on handle 2, one end
// each, nudging 0.01 and 0.1; with the page's Reduce Motion switch on the
// probe holds the `preview-stopped` mark of series `curve-preview` (#343).
// SJ24 pins `-SuiteGalleryWidth` at 200, 240, 280 and 360: section headers
// and the full-width Skew row share their edges (±0.5 pt), the X field and the
// Cap menu share their trailing edge, and the X and Cap labels sit inside
// their rows (QB-S19). SP1, SP6, SP7 and the chip press report `bar-slider`
// and `exact-field`, `slider-key`, `curve-drag` and `press` (each at least 60
// samples, `expectValid`). Points are found from the plot geometry the
// editors draw with (inset SuiteSpacing.m, 12 pt), and clicked at their
// centre rather than through their element (#1795).
import AppKit
import XCTest

extension SuiteJourneyTests {
    /// SJ16: the tone curve adds, moves, nudges, steps, drags out and deletes points.
    @MainActor func testToneCurveAddMoveRemove() throws {
        try walkToneCurve()
    }

    /// SJ20: the easing handles drag and nudge, and Reduce Motion stops the preview dot.
    @MainActor func testEasingCurveHandles() throws {
        try walkEasingCurve()
    }

    /// SJ24: the inspector's rows and values line up at every panel width (QB-S19).
    @MainActor func testInspectorRowsAlignAtEveryWidth() throws {
        for width in [200, 240, 280, 360] { try checkInspectorRows(width: width) }
    }

    /// SP1: velocity scrubs of the bar slider and the exact field (report-only).
    @MainActor func testBarSliderScrubLatency() throws {
        let gallery = curvesGallery("inspector", probe: true)
        gallery.velocityDrag(
            on: "suite.gallery.inspector.rotation", from: CGVector(dx: 0.5, dy: 0.5),
            through: [CGVector(dx: 0.9, dy: 0.5), CGVector(dx: 0.1, dy: 0.5), CGVector(dx: 0.9, dy: 0.5)],
            to: CGVector(dx: 0.5, dy: 0.5))
        let field = curvesControl("suite.gallery.inspector.x", gallery)
        let from = field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        for dx: CGFloat in [300, -300] {
            from.click(
                forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: dx, dy: 0)),
                withVelocity: curvesVelocity, thenHoldForDuration: 0.05)
        }
        gallery.shot("inspector-scrub-perf")
        guard let document = gallery.perf() else { return }
        gallery.expectValid(document, series: "bar-slider")
        gallery.expectValid(document, series: "exact-field")
    }

    /// SP6: 70 arrow steps on the focused bar slider (report-only).
    @MainActor func testSliderKeyLatency() throws {
        let gallery = curvesGallery("inspector", probe: true)
        // A short drag gives the bar the keys without opening its typing field.
        let bar = curvesControl("suite.gallery.inspector.rotation", gallery)
        let from = bar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 10, dy: 0)))
        for step in 0..<70 { gallery.press(step.isMultiple(of: 2) ? .rightArrow : .leftArrow) }
        gallery.shot("inspector-slider-key-perf")
        guard let document = gallery.perf() else { return }
        gallery.expectValid(document, series: "slider-key")
    }

    /// SP7: velocity drags of a tone point around its well (report-only).
    @MainActor func testCurveDragLatency() throws {
        let gallery = curvesGallery("curves", probe: true)
        let tone = curvesControl("suite.gallery.curves.tone", gallery)
        let path: [CGPoint] = [
            CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.4, y: 0.9), CGPoint(x: 0.6, y: 0.1), CGPoint(x: 0.4, y: 0.9),
            CGPoint(x: 0.6, y: 0.1), CGPoint(x: 0.5, y: 0.5),
        ]
        for (from, to) in zip(path, path.dropFirst()) {
            toneSpot(from, tone).click(
                forDuration: 0.05, thenDragTo: toneSpot(to, tone), withVelocity: curvesVelocity, thenHoldForDuration: 0.05)
        }
        gallery.shot("curves-drag-perf")
        guard let document = gallery.perf() else { return }
        gallery.expectValid(document, series: "curve-drag")
    }

    /// The chip press: 70 clicks on the Onion switch report `press` (report-only).
    @MainActor func testChipPressLatency() throws {
        let gallery = curvesGallery("inspector", probe: true)
        let chip = curvesControl("suite.gallery.inspector.chip-onion", gallery)
        for _ in 0..<70 { chip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click() }
        gallery.shot("inspector-chip-press-perf")
        guard let document = gallery.perf() else { return }
        gallery.expectValid(document, series: "press")
    }

    // MARK: - SJ16

    @MainActor private func walkToneCurve() throws {
        let gallery = curvesGallery("curves", probe: false)
        let log = curvesLog(gallery)
        let tone = curvesControl("suite.gallery.curves.tone", gallery)

        // 1. A click on the empty spot (0.25, 0.75) adds Point 2 there: one end.
        toneSpot(CGPoint(x: 0.25, y: 0.75), tone).click()
        curvesExpect(["points 4", "tone ends 1"], log)
        let added = curvesPoint(tonePoint(2, gallery))
        XCTAssertEqual(added?.x ?? -1, 0.25, accuracy: 0.03, "the added point isn't at x 0.25")
        XCTAssertEqual(added?.y ?? -1, 0.75, accuracy: 0.03, "the added point isn't at y 0.75")
        gallery.shot("curves-tone-added")

        // 2. Drag it 20 pt up: it rises, one end.
        let start = toneSpot(CGPoint(x: added?.x ?? 0.25, y: added?.y ?? 0.75), tone)
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -20)))
        curvesExpect(["tone ends 2"], log)
        let moved = curvesPoint(tonePoint(2, gallery))
        XCTAssertGreaterThan(moved?.y ?? 0, (added?.y ?? 1) + 0.05, "the dragged point didn't rise")

        // 3. ↑ nudges the focused point 0.01: one end.
        gallery.press(.upArrow)
        curvesExpect(["tone ends 3"], log)
        let nudged = curvesPoint(tonePoint(2, gallery))
        XCTAssertEqual((nudged?.y ?? 0) - (moved?.y ?? 0), 0.01, accuracy: 0.001, "↑ didn't nudge the point 0.01")

        // 4. Tab moves focus to Point 3 (0.5, 0.5): ↑ now nudges it, not Point 2.
        gallery.press(.tab)
        gallery.press(.upArrow)
        curvesExpect(["tone ends 4"], log)
        XCTAssertEqual(curvesPoint(tonePoint(3, gallery))?.y ?? 0, 0.51, accuracy: 0.001, "Tab didn't move focus to Point 3")
        XCTAssertEqual(curvesPoint(tonePoint(2, gallery))?.y ?? 0, nudged?.y ?? 1, accuracy: 0.001, "Point 2 moved after Tab")
        gallery.shot("curves-tone-focused")

        // 5. Point 3 dragged far below the well goes: one end.
        let third = toneSpot(CGPoint(x: 0.5, y: 0.51), tone)
        third.press(forDuration: 0.1, thenDragTo: third.withOffset(CGVector(dx: 0, dy: tone.frame.height)))
        curvesExpect(["points 3", "tone ends 5"], log)

        // 6. Click Point 2 to focus it (no change, no end), then Delete removes it: one end.
        toneSpot(CGPoint(x: nudged?.x ?? 0.25, y: nudged?.y ?? 0.8), tone).click()
        gallery.press(.delete)
        curvesExpect(["points 2", "tone ends 6"], log)
        XCTAssertFalse(tonePoint(3, gallery).exists, "a third point is left after Delete")
        gallery.shot("curves-tone-deleted")

        // 7. The ends can't go: Delete and Forward Delete on each change nothing and give no end.
        for end in [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] {
            toneSpot(end, tone).click()
            gallery.press(.delete)
            gallery.press(.forwardDelete)
        }
        let lines = curvesLines(log)
        XCTAssertEqual(lines.last { $0.contains(" ends ") }, "tone ends 6", "Delete on an end gave an end")
        XCTAssertEqual(lines.last { $0.hasPrefix("points ") }, "points 2", "Delete on an end removed it")
        XCTAssert(tonePoint(1, gallery).exists && tonePoint(2, gallery).exists, "an end point went")
    }

    // MARK: - SJ20

    @MainActor private func walkEasingCurve() throws {
        let gallery = curvesGallery("curves", probe: true)
        let log = curvesLog(gallery)
        let easing = curvesControl("suite.gallery.curves.easing", gallery)
        let first = curvesControl("suite.gallery.curves.easing.handle1", gallery)
        let second = curvesControl("suite.gallery.curves.easing.handle2", gallery)
        let before = curvesPoint(first)

        // 1. Drag handle 1 from (0.42, 0) 20 pt up: it rises, one end.
        let handle = easingSpot(CGPoint(x: 0.42, y: 0), easing)
        handle.press(forDuration: 0.1, thenDragTo: handle.withOffset(CGVector(dx: 0, dy: -20)))
        curvesExpect(["easing ends 1"], log)
        XCTAssertGreaterThan(curvesPoint(first)?.y ?? 0, (before?.y ?? 1) + 0.05, "handle 1 didn't rise")
        XCTAssert(curvesLines(log).contains { $0.hasPrefix("handle1 ") }, "the drag logged no handle1 move")

        // 2. Tab moves to handle 2 (0.58, 1); ↑ nudges it 0.01 and ⇧↑ 0.1, one end each.
        let start = curvesPoint(second)?.y ?? 0
        gallery.press(.tab)
        gallery.press(.upArrow)
        curvesExpect(["easing ends 2"], log)
        XCTAssertEqual((curvesPoint(second)?.y ?? 0) - start, 0.01, accuracy: 0.001, "↑ didn't nudge handle 2 by 0.01")
        gallery.press(.upArrow, .shift)
        curvesExpect(["easing ends 3"], log)
        XCTAssertEqual((curvesPoint(second)?.y ?? 0) - start, 0.11, accuracy: 0.001, "⇧↑ didn't nudge handle 2 by 0.1")
        gallery.shot("curves-easing-nudged")

        // 3. Reduce Motion on: the preview dot stops (`preview-stopped`, series `curve-preview`).
        curvesControl("suite.gallery.curves.reduce-motion", gallery).click()
        gallery.shot("curves-reduce-motion")
        guard let document = gallery.perf() else { return }
        let marks = document.marks.filter { $0.series == "curve-preview" }
        XCTAssertEqual(marks.last?.name, "preview-stopped", "Reduce Motion left the preview dot playing: \(marks)")
    }

    // MARK: - SJ24

    @MainActor private func checkInspectorRows(width: Int) throws {
        let gallery = curvesGallery("inspector", probe: false, extra: ["-SuiteGalleryWidth", "\(width)"])
        let headers = ["transform", "style", "motion"].map { curvesControl("suite.inspector.section.\($0)", gallery).frame }
        let row = curvesControl("suite.gallery.inspector.skew", gallery).frame
        for (name, header) in zip(["Transform", "Style", "Motion"], headers) {
            XCTAssertEqual(header.minX, row.minX, accuracy: 0.5, "\(width) pt: \(name)'s header and the rows start apart")
            XCTAssertEqual(header.maxX, row.maxX, accuracy: 0.5, "\(width) pt: \(name)'s header and the rows end apart")
        }
        let x = curvesControl("suite.gallery.inspector.x", gallery).frame
        let cap = curvesControl("suite.gallery.inspector.cap", gallery).frame
        XCTAssertEqual(x.maxX, cap.maxX, accuracy: 0.5, "\(width) pt: the X and Cap values end apart")
        let root = gallery.element("suite.gallery.inspector")
        for (label, value) in [("X", x), ("Cap", cap)] {
            let text = root.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
            XCTAssert(text.waitForExistence(timeout: 5), "\(width) pt: no \(label) label")
            for (what, frame) in [("label", text.frame), ("value", value)] {
                XCTAssert(
                    frame.minX >= row.minX - 0.5 && frame.maxX <= row.maxX + 0.5,
                    "\(width) pt: \(label)'s \(what) \(frame) leaves its row \(row.minX)...\(row.maxX)")
            }
            XCTAssertLessThan(text.frame.maxX, value.minX + 0.5, "\(width) pt: \(label)'s label runs into its value")
            XCTAssertEqual(text.frame.midY, value.midY, accuracy: 7, "\(width) pt: \(label)'s label isn't on its value's row")
        }
        gallery.shot("inspector-width-\(width)")
    }

    // MARK: - Helpers

    /// 300 pt a second, as XCUIGestureVelocity counts pixels a second.
    private var curvesVelocity: XCUIGestureVelocity {
        XCUIGestureVelocity(300 * (NSScreen.main?.backingScaleFactor ?? 1))
    }

    /// Library on gallery page `page`, with the perf probe when `probe`.
    @MainActor private func curvesGallery(_ page: String, probe: Bool, extra: [String] = []) -> Journey {
        let arguments = ["-SuiteGallery", page] + (probe ? ["-SuitePerfProbe"] : []) + extra
        let gallery = Journey("Library", self, name: "suiteui", arguments: arguments)
        XCTAssert(gallery.element("suite.gallery.\(page)").waitForExistence(timeout: 30), "no \(page) page")
        return gallery
    }

    /// The element `id`: when the identifier lands on several (a row's label and its control), the
    /// largest that isn't a text or an image.
    @MainActor private func curvesControl(_ id: String, _ gallery: Journey) -> XCUIElement {
        let first = gallery.element(id)
        XCTAssert(first.waitForExistence(timeout: 10), "no \(id)")
        let all = gallery.app.descendants(matching: .any).matching(identifier: id).allElementsBoundByIndex
        let controls = all.filter { $0.elementType != .staticText && $0.elementType != .image }
        return controls.max { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height } ?? first
    }

    /// Tone point `n` (1-based), `suite.gallery.curves.tone.point<n>`.
    @MainActor private func tonePoint(_ n: Int, _ gallery: Journey) -> XCUIElement {
        gallery.element("suite.gallery.curves.tone.point\(n)")
    }

    /// The screen point of unit point `unit` on the tone well: a centred square inset 12 pt, y up.
    @MainActor private func toneSpot(_ unit: CGPoint, _ tone: XCUIElement) -> XCUICoordinate {
        let size = tone.frame.size
        let side = max(min(size.width, size.height) - 24, 0)
        let x = (size.width - side) / 2 + unit.x * side
        let y = (size.height - side) / 2 + (1 - unit.y) * side
        return tone.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    /// The screen point of unit point `unit` on the easing well: inset 12 pt, y over -0.25...1.25.
    @MainActor private func easingSpot(_ unit: CGPoint, _ easing: XCUIElement) -> XCUICoordinate {
        let plot = CGSize(width: easing.frame.width - 24, height: easing.frame.height - 24)
        let x = 12 + unit.x * plot.width
        let y = 12 + (1.25 - unit.y) / 1.5 * plot.height
        return easing.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y))
    }

    /// A point's or handle's accessibility value, "x 0.42, y 0.10", as numbers.
    @MainActor private func curvesPoint(_ element: XCUIElement) -> CGPoint? {
        guard element.waitForExistence(timeout: 5), let value = element.value as? String else { return nil }
        let numbers = value.split { $0 == "," || $0 == " " }.compactMap { Double($0) }
        guard numbers.count == 2 else { return nil }
        return CGPoint(x: numbers[0], y: numbers[1])
    }

    /// The page's `suite.gallery.log`.
    @MainActor private func curvesLog(_ gallery: Journey) -> XCUIElement {
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log")
        return log
    }

    /// The log's lines, its value or (when that is empty) its label.
    @MainActor private func curvesLines(_ log: XCUIElement) -> [String] {
        let value = log.value as? String ?? ""
        return (value.isEmpty ? log.label : value).split(separator: "\n").map(String.init)
    }

    /// Waits up to 3 s for every line of `expected` in the log.
    @MainActor private func curvesExpect(_ expected: [String], _ log: XCUIElement, line: UInt = #line) {
        var lines: [String] = []
        for _ in 0..<15 {
            lines = curvesLines(log)
            if expected.allSatisfy(lines.contains) { return }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTFail("the log has no \(expected.filter { !lines.contains($0) }); it ends \(lines.suffix(5))", line: line)
    }
}
