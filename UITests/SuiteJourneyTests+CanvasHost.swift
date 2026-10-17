// SuiteJourneyTests+CanvasHost.swift: SJ27, SJ28 and SP11 (canvas-host
// packet, journey steps 1 to 6), on the gallery's fakes. SJ27 drags across
// the `canvas-host` page's fake document: the drag reaches the page's
// delegate, whose log shows exactly one `endDrag` (the mouse-up commit). The
// window body count is the render budget's
// (RenderBudgetCanvasHostTests.dragRunsNoBodies), which a UI test can't read.
// SJ28 opens the `settings-rendering` page's Rendering pull-down, picks GPU
// (Metal), then CPU, and reopens it after each pick: the status line under the
// three choices reads the backend picked. SP11 drags 600 pt at 300 pt a
// second and reports the `canvas-drag` series: the `suite.perf` samples when
// the host records them, else the samples the delegate counted, report-only.
// Both read the log through `logText`: macOS gives a Text's string as `value`.
import AppKit
import XCTest

extension SuiteJourneyTests {
    /// SJ27: a drag on the canvas host reaches the delegate and commits once on mouse-up.
    @MainActor func testCanvasHostDragsWithoutBodies() throws {
        let gallery = openCanvasHostPage(CanvasHostPages.canvasHost)
        let canvas = gallery.element(CanvasHostIDs.canvas)
        XCTAssert(canvas.waitForExistence(timeout: 10), "no \(CanvasHostIDs.canvas) on the canvas-host page")
        gallery.shot("canvas-host")
        gallery.velocityDrag(
            on: CanvasHostIDs.canvas, from: CGVector(dx: 0.3, dy: 0.5), to: CGVector(dx: 0.7, dy: 0.5),
            step: "canvas-host-dragged")
        let log = gallery.element(CanvasHostIDs.log)
        XCTAssert(log.waitForExistence(timeout: 5), "no \(CanvasHostIDs.log) under the canvas")
        let text = logText(log)
        let ends = endDragSamples(in: text)
        XCTAssertEqual(ends.count, 1, "the drag should end once, the log reads: \(text)")
        XCTAssertGreaterThan(ends.first ?? 0, 0, "the drag never reached the delegate, the log reads: \(text)")
    }

    /// SJ28: each pick in the Rendering pull-down moves its status line to the backend picked.
    @MainActor func testRenderingPaneSwitchesBackend() throws {
        let gallery = openCanvasHostPage(CanvasHostPages.settingsRendering)
        let menu = gallery.element(CanvasHostIDs.menu)
        XCTAssert(menu.waitForExistence(timeout: 10), "no \(CanvasHostIDs.menu) on the settings-rendering page")
        for (title, backend) in [("GPU (Metal)", "GPU"), ("CPU", "CPU")] {
            menu.click()
            let item = gallery.app.menuItems[title].firstMatch
            XCTAssert(item.waitForExistence(timeout: 5), "the Rendering menu shows no \(title)")
            item.click()
            menu.click()
            let status = statusLine(gallery)
            XCTAssert(status.waitForExistence(timeout: 5), "the Rendering menu shows no status line after \(title)")
            XCTAssertEqual(status.title, "Drawing on \(backend)", "the status line after picking \(title)")
            gallery.shot("rendering-menu-\(gallery.slug(backend))", screen: true)
            gallery.app.typeKey(.escape, modifierFlags: [])
        }
    }

    /// SP11: `canvas-drag` on the host, 600 pt at 300 pt a second, reported.
    @MainActor func testCanvasHostDragLatency() throws {
        let gallery = openCanvasHostPage(CanvasHostPages.canvasHost)
        let canvas = gallery.element(CanvasHostIDs.canvas)
        XCTAssert(canvas.waitForExistence(timeout: 10), "no \(CanvasHostIDs.canvas) on the canvas-host page")
        let reach = min(600, canvas.frame.width * 0.8) / max(canvas.frame.width, 1)
        let velocity = XCUIGestureVelocity(300 * (NSScreen.main?.backingScaleFactor ?? 1))
        gallery.velocityDrag(
            on: CanvasHostIDs.canvas, from: CGVector(dx: 0.5 - reach / 2, dy: 0.5),
            to: CGVector(dx: 0.5 + reach / 2, dy: 0.5), velocity: velocity, step: "canvas-host-drag-perf")
        let log = gallery.element(CanvasHostIDs.log)
        let text = logText(log)
        let delegated = endDragSamples(in: text).last ?? 0
        let probed = gallery.perf()?.latency["canvas-drag"]
        let line = probed.map { "SP11 canvas-drag: samples=\($0.count) frames-late-p95=\($0.p95FramesLate) report-only (suite.perf)" }
            ?? "SP11 canvas-drag: samples=\(delegated) frames-late-p95=n/a report-only (delegate samples; the host records no suite.perf series)"
        print(line)
        let attachment = XCTAttachment(string: line)
        attachment.name = "perf-report-canvas-drag"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThan(probed?.count ?? delegated, 0, "the canvas-drag series is empty, the log reads: \(text)")
    }

    /// The log's text: a SwiftUI `Text` on macOS exposes its string as the element's
    /// `value` and leaves `label` empty, so read `label` only when it is set.
    @MainActor private func logText(_ log: XCUIElement) -> String {
        log.label.isEmpty ? log.value as? String ?? "" : log.label
    }

    /// The sample count of each `endDrag after N samples` line in the page's log, oldest first.
    private func endDragSamples(in log: String) -> [Int] {
        log.split(separator: "\n").compactMap { line in
            guard line.hasPrefix("endDrag after ") else { return nil }
            return Int(line.dropFirst("endDrag after ".count).prefix { $0.isNumber })
        }
    }

    /// The open Rendering menu's disabled status line, "Drawing on <backend>" or a note.
    @MainActor private func statusLine(_ gallery: Journey) -> XCUIElement {
        let byID = gallery.app.menuItems[CanvasHostIDs.status].firstMatch
        if byID.waitForExistence(timeout: 2) { return byID }
        return gallery.app.menuItems.matching(NSPredicate(format: "title BEGINSWITH 'Drawing on'")).firstMatch
    }

    /// The pages, and the ids `RenderingControlID` names in SuiteUI (this target doesn't link SuiteUI).
    private enum CanvasHostPages {
        static let canvasHost = "canvas-host"
        static let settingsRendering = "settings-rendering"
    }

    private enum CanvasHostIDs {
        static let canvas = "suite.canvas"
        static let log = "suite.gallery.canvas-host.log"
        static let menu = "suite.menu.rendering"
        static let status = "suite.settings.rendering.status"
    }

    /// The gallery opened at `page` on the fakes with the perf probe, its root on screen.
    @MainActor private func openCanvasHostPage(_ page: String) -> Journey {
        let gallery = Journey(
            "Library", self, name: "suiteui", arguments: ["-SuiteGallery", page, "-SuiteGalleryFakes", "-SuitePerfProbe"])
        XCTAssert(gallery.element("suite.gallery.\(page)").waitForExistence(timeout: 30), "no \(page) page")
        return gallery
    }
}
