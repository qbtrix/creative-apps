// SuiteJourneyTests+CanvasMarks.swift: SJ21, SP2 and SP5, CM-13 (packet
// docs/blueprints/suiteui/features/canvas-marks.md, Journey steps 3 and 5).
// SJ21, on `marks`: the page logs `point WxH zoom z` and `grid v×h` (with
// `hits …` or `handles none`) into `suite.gallery.log` on appear and after
// each chip. The point mark's logged size is the same at zoom 1 and 4
// (`suite.gallery.marks.zoom`); the 3-cell grid logs 2 lines each way and
// none with `suite.gallery.marks.grid` off; `suite.gallery.marks.selection`
// off logs `handles none`; a drag through the point mark at document
// (320,80) still logs `drag … ends n` (the mark takes no click). "Over light
// and dark pixels" runs the whole walk in Light and again in Dark
// (`-AppleInterfaceStyle Dark` first, as SJ testEditorWindowDark does), so
// the mark sits on the artboard in both appearances; the page has no image
// of its own to put light and dark pixels under one mark (the snapshot
// `SuitePointMarkSnapshots` covers that). SP2 drags 360 pt across `canvas`
// (series `canvas-drag`), SP5 drags the selection's bottom-right handle
// (document (220,180) of the box (60,60,160,120) at zoom 1) 360 pt on
// `marks` (series `handle-drag`), both at 300 pt a second and report-only.
// The gallery's `suiteProbes()` records no component series yet (#2784), so
// either series can read 0 samples today: the journey reports that and
// fails nothing on it; once samples arrive, `expectValid` holds it to 60.
// Points on the document are normalized offsets of `suite.canvas.artboard`,
// whose frame is the document at the page's zoom.
import AppKit
import XCTest

extension SuiteJourneyTests {
    /// SJ21: the point mark keeps its size across zoom, the grid logs cells − 1 lines, a drag passes through.
    @MainActor func testPointAndGridMarks() throws {
        for dark in [false, true] {
            let gallery = marksOpen("marks", dark: dark)
            marksWalk(gallery, suffix: dark ? "-dark" : "")
            gallery.app.terminate()
        }
    }

    /// SP2: a 360 pt drag across `canvas` at 300 pt a second, series `canvas-drag` (QB-S3, report-only).
    @MainActor func testCanvasDragLatency() throws {
        let gallery = marksOpen("canvas", dark: false, probe: true)
        let log = marksLog(gallery)
        gallery.velocityDrag(
            on: "suite.canvas.artboard", from: marksOffset(20, 150), to: marksOffset(380, 150),
            velocity: marksVelocity, step: "canvas-drag-perf")
        XCTAssert(marksWait { self.marksDragStarts(at: CGPoint(x: 20, y: 150), self.marksLines(log).last) },
                  "the drag didn't log its end from (20,150): \(marksLines(log).suffix(3))")
        marksReport(gallery, row: "SP2", series: "canvas-drag")
    }

    /// SP5: the selection's bottom-right handle dragged 360 pt at 300 pt a second, series `handle-drag` (QB-S4, report-only).
    @MainActor func testHandleDragLatency() throws {
        let gallery = marksOpen("marks", dark: false, probe: true)
        let log = marksLog(gallery)
        XCTAssert(marksWait { self.marksLast("hits ", log) != nil }, "the marks page logged no handles")
        gallery.velocityDrag(
            on: "suite.canvas.artboard", from: marksOffset(220, 180), to: marksOffset(220 + 300, 180 + 200),
            velocity: marksVelocity, step: "handle-drag-perf")
        XCTAssert(marksWait { self.marksLines(log).last?.hasPrefix("rect (60,60) ") == true },
                  "the handle drag didn't end with the box at (60,60): \(marksLines(log).suffix(3))")
        XCTAssert(marksLines(log).contains("handle bottomRight"), "the drag didn't take bottomRight: \(marksLines(log).suffix(4))")
        marksReport(gallery, row: "SP5", series: "handle-drag")
    }

    /// The SJ21 steps on one launch of `marks`; shots end in `suffix`.
    @MainActor private func marksWalk(_ gallery: Journey, suffix: String) {
        let log = marksLog(gallery)
        // 1. On appear at zoom 1: the selection's hits, the point mark, the grid's 2 × 2 lines.
        XCTAssert(marksWait { self.marksLast("point ", log)?.hasSuffix(" zoom 1") == true },
                  "no `point … zoom 1` line on appear: \(marksLines(log).suffix(3))")
        let small = marksPointSize(log)
        XCTAssertNotNil(small, "the point line has no size: \(marksLast("point ", log) ?? "none")")
        XCTAssertEqual(marksLast("grid ", log), "grid 2×2", "a 3-cell grid logs cells − 1 lines each way")
        XCTAssertNotNil(marksLast("hits ", log), "the selection logged no hit frames")
        gallery.shot("marks-zoom-1\(suffix)")

        // 2. Zoom 4: the point mark's on-screen size is unchanged; the grid still logs 2 × 2.
        marksToggle("zoom", gallery)
        XCTAssert(marksWait { self.marksLast("point ", log)?.hasSuffix(" zoom 4") == true },
                  "the zoom chip logged no `point … zoom 4`: \(marksLines(log).suffix(3))")
        XCTAssertEqual(marksPointSize(log), small, "the point mark's size changed between zoom 1 and 4")
        XCTAssertEqual(marksLast("grid ", log), "grid 2×2", "the grid's line count changed with the zoom")
        gallery.shot("marks-zoom-4\(suffix)")
        marksToggle("zoom", gallery)
        XCTAssert(marksWait { self.marksLast("point ", log)?.hasSuffix(" zoom 1") == true }, "the zoom chip didn't go back to 1")
        XCTAssertEqual(marksPointSize(log), small, "the point mark's size changed back at zoom 1")

        // 3. Grid off: cells 0 logs no lines; on again, 2 × 2.
        marksToggle("grid", gallery)
        XCTAssert(marksWait { self.marksLines(log).last == "grid 0×0" }, "grid off didn't log `grid 0×0`: \(marksLines(log).suffix(3))")
        gallery.shot("marks-grid-off\(suffix)")
        marksToggle("grid", gallery)
        XCTAssert(marksWait { self.marksLines(log).last == "grid 2×2" }, "grid on didn't log `grid 2×2`: \(marksLines(log).suffix(3))")

        // 4. Selection off: the readout says no handles.
        marksToggle("selection", gallery)
        XCTAssert(marksWait { self.marksLines(log).suffix(3).first == "handles none" },
                  "selection off didn't log `handles none`: \(marksLines(log).suffix(3))")
        gallery.shot("marks-no-selection\(suffix)")

        // 5. A drag through the point mark at (320,80): the canvas under it still takes it.
        let before = marksDragEnds(log)
        gallery.velocityDrag(on: "suite.canvas.artboard", from: marksOffset(290, 80), to: marksOffset(350, 80))
        XCTAssert(marksWait { self.marksDragEnds(log) == before + 1 },
                  "the drag through the point mark logged no `drag … ends`: \(marksLines(log).suffix(3))")
        let line = marksLines(log).last ?? ""
        XCTAssert(marksDragStarts(at: CGPoint(x: 290, y: 80), line) && line.hasSuffix(" ends \(before + 1)"),
                  "the drag through the point mark logged \(line)")
        gallery.shot("marks-dragged-through-point\(suffix)")
    }

    /// 300 pt a second, as XCUIGestureVelocity counts pixels a second.
    @MainActor private var marksVelocity: XCUIGestureVelocity {
        XCUIGestureVelocity(300 * (NSScreen.main?.backingScaleFactor ?? 1))
    }

    /// The gallery on `page`, in Dark when `dark` (the appearance pair first), with the probes when `probe`.
    @MainActor private func marksOpen(_ page: String, dark: Bool, probe: Bool = false) -> Journey {
        let appearance = dark ? ["-AppleInterfaceStyle", "Dark"] : []
        let arguments = appearance + ["-SuiteGallery", page] + (probe ? ["-SuitePerfProbe"] : [])
        let gallery = Journey("Library", self, name: "suiteui", arguments: arguments)
        XCTAssert(gallery.element("suite.gallery.\(page)").waitForExistence(timeout: 30), "no gallery page \(page)")
        XCTAssert(gallery.element("suite.canvas.artboard").waitForExistence(timeout: 10), "no suite.canvas.artboard on \(page)")
        return gallery
    }

    /// The page's `suite.gallery.log`.
    @MainActor private func marksLog(_ gallery: Journey) -> XCUIElement {
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log")
        return log
    }

    /// Clicks the chip `suite.gallery.marks.<name>`.
    @MainActor private func marksToggle(_ name: String, _ gallery: Journey) {
        let chip = gallery.element("suite.gallery.marks.\(name)")
        XCTAssert(chip.waitForExistence(timeout: 5), "no suite.gallery.marks.\(name) chip")
        chip.click()
    }

    /// Document pixel (`x`, `y`) of the 400 × 300 document as a normalized offset of `suite.canvas.artboard`.
    private func marksOffset(_ x: CGFloat, _ y: CGFloat) -> CGVector {
        CGVector(dx: x / 400, dy: y / 300)
    }

    /// The size the newest `point WxH zoom z` line logs, "WxH".
    @MainActor private func marksPointSize(_ log: XCUIElement) -> String? {
        let words = (marksLast("point ", log) ?? "").split(separator: " ")
        return words.count == 4 ? String(words[1]) : nil
    }

    /// The `n` of the newest `drag … ends n` line, 0 before any.
    @MainActor private func marksDragEnds(_ log: XCUIElement) -> Int {
        let line = marksLines(log).last { $0.hasPrefix("drag ") && $0.contains(" ends ") } ?? ""
        return line.split(separator: " ").last.flatMap { Int($0) } ?? 0
    }

    /// Whether `line` is a `drag (x,y)→… ends n` line whose start is within 2 px of `point`
    /// (the artboard can sit on a half point, so a pixel can round either way).
    private func marksDragStarts(at point: CGPoint, _ line: String?) -> Bool {
        guard let line, line.hasPrefix("drag ("), line.contains(" ends ") else { return false }
        let xy = line.dropFirst("drag (".count).prefix { $0 != ")" }.split(separator: ",").compactMap { Double($0) }
        guard xy.count == 2 else { return false }
        return abs(xy[0] - Double(point.x)) <= 2 && abs(xy[1] - Double(point.y)) <= 2
    }

    /// The newest log line that starts with `prefix`.
    @MainActor private func marksLast(_ prefix: String, _ log: XCUIElement) -> String? {
        marksLines(log).last { $0.hasPrefix(prefix) }
    }

    /// The log's lines: its value when it has one, else its label.
    @MainActor private func marksLines(_ log: XCUIElement) -> [String] {
        let value = log.value as? String ?? ""
        return (value.isEmpty ? log.label : value).split(separator: "\n").map(String.init)
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func marksWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    /// Reports `series` from `suite.perf` as "perf-report-<series>", report-only. No series
    /// yet (#2784: suiteProbes records no component series) fails nothing; a series with
    /// samples must hold `Journey.minimumSamples`.
    @MainActor private func marksReport(_ gallery: Journey, row: String, series: String) {
        let document = gallery.perf()
        let summary = document?.latency[series]
        let line = summary.map { "\(row) \(series): samples=\($0.count) frames-late-p95=\($0.p95FramesLate) report-only" }
            ?? "\(row) \(series): samples=0 frames-late-p95=n/a report-only (no suite.perf series yet, #2784)"
        print(line)
        let attachment = XCTAttachment(string: line)
        attachment.name = "perf-report-\(series)"
        attachment.lifetime = .keepAlways
        add(attachment)
        if let document, (summary?.count ?? 0) > 0 { gallery.expectValid(document, series: series) }
    }
}
