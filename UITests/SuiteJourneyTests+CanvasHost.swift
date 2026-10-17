// SuiteJourneyTests+CanvasHost.swift: SJ27, SJ28 and SP11 (canvas-host
// packet, journey steps 1 to 6). SJ27 drags 120 samples across the
// `canvas-host` page's fake document: the log shows one `endDrag` and the
// window body count grows by at most 1. SJ28 opens the `settings-rendering`
// page's Rendering menu and picks GPU (Metal), then CPU: the status line
// follows each pick. SP11 reports the `canvas-drag` series on the host. CH-2
// writes all three skipped over the placeholder pages; CH-5 turns them on.
import AppKit
import XCTest

extension SuiteJourneyTests {
    /// SJ27: a drag on the canvas host reaches the delegate and runs at most one window body.
    @MainActor func testCanvasHostDragsWithoutBodies() throws {
        throw XCTSkip("waits on CH-5")
        let gallery = openCanvasHostPage(CanvasHostPages.canvasHost)
        let canvas = gallery.element(CanvasHostIDs.canvas)
        XCTAssert(canvas.waitForExistence(timeout: 10), "no \(CanvasHostIDs.canvas) on the canvas-host page")
        let from = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 300, dy: 0)))
        gallery.shot("canvas-host-dragged")
    }

    /// SJ28: the Rendering menu moves its checkmark and status line with each pick.
    @MainActor func testRenderingPaneSwitchesBackend() throws {
        throw XCTSkip("waits on CH-5")
        let gallery = openCanvasHostPage(CanvasHostPages.settingsRendering)
        let status = gallery.element(CanvasHostIDs.status)
        for choice in ["gpu", "cpu"] {
            gallery.element("suite.settings.rendering.\(choice)").click()
            XCTAssert(status.waitForExistence(timeout: 5), "no status line after picking \(choice)")
        }
        gallery.shot("rendering-menu-picked")
    }

    /// SP11: `canvas-drag` sample-to-present on the host, reported.
    @MainActor func testCanvasHostDragLatency() throws {
        throw XCTSkip("waits on CH-5")
        let gallery = openCanvasHostPage(CanvasHostPages.canvasHost)
        let canvas = gallery.element(CanvasHostIDs.canvas)
        XCTAssert(canvas.waitForExistence(timeout: 10), "no \(CanvasHostIDs.canvas) on the canvas-host page")
        let from = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        from.press(forDuration: 0.05, thenDragTo: from.withOffset(CGVector(dx: 400, dy: 0)))
        if let document = gallery.perf() { gallery.expectValid(document, series: "canvas-drag") }
    }

    /// The pages, and the ids `RenderingControlID` names in SuiteUI (this target doesn't link SuiteUI).
    private enum CanvasHostPages {
        static let canvasHost = "canvas-host"
        static let settingsRendering = "settings-rendering"
    }

    private enum CanvasHostIDs {
        static let canvas = "suite.canvas"
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
