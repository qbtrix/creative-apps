// SuiteJourneyTests+Parity.swift: the parity journey (EW-J7,
// docs/blueprints/suiteui/features/editor-in-window.md). It launches Flare,
// Design, Photo and Halo one after another at `-SuiteWindowSize 1024x768`
// with a document open, and shoots each under `suiteui` so the contact sheet
// lists them side by side: `parity-<app>-window`, the `suite.tools` palette as
// `parity-<app>-palette` (Halo has none) and `suite.switcher` as
// `parity-<app>-switcher` when the window has one. None of these shots is
// audited: the other apps' counts belong to their own keys. Flare opens File >
// Open Sample > Keyed Ball, as its own journeys do (its toolbar has no sample
// button since #1608, #1627 and #1673). All four apps are on SuiteWindow now
// (Design #1391, Photo's shell parity), which takes the size flag, so each
// window must lie inside the display's visible frame. Flare's height check is
// an expected failure until its inspector scrolls (#1425); its width, x and
// top checks stay strict.
// testAppsSideBySide sorts before
// testEveryControlMeetsHitSize, so it is never the class's last test.
import AppKit
import XCTest

extension SuiteJourneyTests {
    @MainActor func testAppsSideBySide() {
        let size = ["-SuiteWindowSize", "1024x768"]

        let flare = Journey("Flare", self, name: "suiteui", arguments: size)
        openSample(flare, "Keyed Ball")
        XCTAssert(flare.element("suite.tools").waitForExistence(timeout: 10), "Open Sample > Keyed Ball showed no palette")
        shootParity(flare, app: "flare", palette: true)

        let design = Journey("Design", self, name: "suiteui", arguments: size)
        design.app.typeKey("n", modifierFlags: .command)
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "Design's ⌘N showed no canvas")
        shootParity(design, app: "design", palette: true)

        // A fresh recovery folder, as photoArguments() gives Photo's own journeys.
        let recovery = FileManager.default.temporaryDirectory.appending(path: "parity-recovery-\(UUID().uuidString)")
        let photo = Journey("Photo", self, name: "suiteui", arguments: size + ["-PhotoRecoveryDir", recovery.path])
        photo.app.typeKey("n", modifierFlags: .command)
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 10), "Photo's ⌘N showed no canvas")
        shootParity(photo, app: "photo", palette: true)

        let halo = Journey("Halo", self, name: "suiteui", arguments: size + ["-HaloSample", "three-layers"])
        XCTAssert(halo.element("halo.timeline").waitForExistence(timeout: 30), "-HaloSample opened no timeline")
        shootParity(halo, app: "halo", palette: false)
    }

    /// File > Open Sample > `title`, the menu path Flare's own journeys take
    /// (Journey.openSample in FlareJourneyTests+Menus.swift, which this bundle
    /// doesn't compile).
    @MainActor private func openSample(_ journey: Journey, _ title: String) {
        journey.app.menuBars.menuBarItems["File"].click()
        let parent = journey.app.menuBars.menuItems["Open Sample"]
        XCTAssert(parent.waitForExistence(timeout: 5), "Flare's File menu has no Open Sample")
        parent.hover()
        let item = parent.menuItems[title]
        XCTAssert(item.waitForExistence(timeout: 5), "File > Open Sample has no \(title)")
        item.click()
    }

    /// Shoots `parity-<app>-window`, the palette and the switcher when there
    /// is one, all unaudited; checks the window lies inside the display's
    /// visible frame; then quits the app.
    @MainActor private func shootParity(_ journey: Journey, app: String, palette: Bool) {
        let window = journey.app.windows.firstMatch
        XCTAssert(window.waitForExistence(timeout: 30), "\(app) opened no window")
        journey.shot("parity-\(app)-window", element: window, audit: false)
        if palette { journey.shot("parity-\(app)-palette", element: journey.element("suite.tools"), audit: false) }
        let switcher = journey.element("suite.switcher")
        if switcher.waitForExistence(timeout: 5) {
            journey.shot("parity-\(app)-switcher", element: switcher, audit: false)
        }
        // Element frames can round to half a point.
        let visible = Self.visibleFrame().insetBy(dx: -1, dy: -1)
        let frame = window.frame
        XCTAssert(
            frame.minX >= visible.minX && frame.maxX <= visible.maxX,
            "\(app)'s window \(frame) runs outside the display's visible frame \(visible) sideways")
        XCTAssert(
            frame.minY >= visible.minY,
            "\(app)'s window \(frame) starts above the display's visible frame \(visible)")
        let fitsHeight = {
            XCTAssert(
                frame.maxY <= visible.maxY,
                "\(app)'s window \(frame) runs below the display's visible frame \(visible)")
        }
        if app == "flare" {
            // Only the height check: Flare's unscrolled inspector stands taller than the frame.
            XCTExpectFailure(
                "Flare's open-document minimum height is taller than the runner's visible frame: #1425",
                strict: false, failingBlock: fitsHeight)
        } else {
            fitsHeight()
        }
        journey.app.terminate()
    }

    /// The primary screen's visible frame (under its menu bar) in top-left
    /// points, the space XCUIElement frames use; NSScreen's starts at the
    /// bottom left.
    @MainActor private static func visibleFrame() -> CGRect {
        guard let screen = NSScreen.screens.first else { return .zero }
        let visible = screen.visibleFrame
        return CGRect(x: visible.minX, y: screen.frame.height - visible.maxY, width: visible.width, height: visible.height)
    }
}
