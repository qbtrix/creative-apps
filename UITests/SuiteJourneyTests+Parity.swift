// SuiteJourneyTests+Parity.swift: the parity journey (EW-J7,
// docs/blueprints/suiteui/features/editor-in-window.md). It launches Flare,
// Design, Photo and Halo one after another at `-SuiteWindowSize 1024x768`
// with a document open, and shoots each under `suiteui` so the contact sheet
// lists them side by side: `parity-<app>-window`, the `suite.tools` palette as
// `parity-<app>-palette` (Halo has none) and `suite.switcher` as
// `parity-<app>-switcher` when the window has one. None of these shots is
// audited: the other apps' counts belong to their own keys. Only an app on
// SuiteWindow takes the size flag, so only those (Flare, Halo) must lie inside
// the display's visible frame; Design and Photo keep EditorShell's size until
// their wave-2 move. testAppsSideBySide sorts before
// testEveryControlMeetsHitSize, so it is never the class's last test.
import AppKit
import XCTest

extension SuiteJourneyTests {
    @MainActor func testAppsSideBySide() {
        let size = ["-SuiteWindowSize", "1024x768"]

        let flare = Journey("Flare", self, name: "suiteui", arguments: size)
        flare.click("New Sample Animation", in: .toolbar)
        XCTAssert(flare.element("suite.tools").waitForExistence(timeout: 10), "New Sample Animation showed no palette")
        shootParity(flare, app: "flare", onSuiteWindow: true, palette: true)

        let design = Journey("Design", self, name: "suiteui", arguments: size)
        design.app.typeKey("n", modifierFlags: .command)
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "Design's ⌘N showed no canvas")
        shootParity(design, app: "design", onSuiteWindow: false, palette: true)

        // A fresh recovery folder, as photoArguments() gives Photo's own journeys.
        let recovery = FileManager.default.temporaryDirectory.appending(path: "parity-recovery-\(UUID().uuidString)")
        let photo = Journey("Photo", self, name: "suiteui", arguments: size + ["-PhotoRecoveryDir", recovery.path])
        photo.app.typeKey("n", modifierFlags: .command)
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 10), "Photo's ⌘N showed no canvas")
        shootParity(photo, app: "photo", onSuiteWindow: false, palette: true)

        let halo = Journey("Halo", self, name: "suiteui", arguments: size + ["-HaloSample", "three-layers"])
        XCTAssert(halo.element("halo.timeline").waitForExistence(timeout: 30), "-HaloSample opened no timeline")
        shootParity(halo, app: "halo", onSuiteWindow: true, palette: false)
    }

    /// Shoots `parity-<app>-window`, the palette and the switcher when there
    /// is one, all unaudited; checks a SuiteWindow app's window lies inside
    /// the display's visible frame; then quits the app.
    @MainActor private func shootParity(_ journey: Journey, app: String, onSuiteWindow: Bool, palette: Bool) {
        let window = journey.app.windows.firstMatch
        XCTAssert(window.waitForExistence(timeout: 30), "\(app) opened no window")
        journey.shot("parity-\(app)-window", element: window, audit: false)
        if palette { journey.shot("parity-\(app)-palette", element: journey.element("suite.tools"), audit: false) }
        let switcher = journey.element("suite.switcher")
        if switcher.waitForExistence(timeout: onSuiteWindow ? 5 : 1) {
            journey.shot("parity-\(app)-switcher", element: switcher, audit: false)
        }
        if onSuiteWindow {
            let visible = Self.visibleFrame()
            // Element frames can round to half a point.
            XCTAssert(
                visible.insetBy(dx: -1, dy: -1).contains(window.frame),
                "\(app)'s window \(window.frame) runs outside the display's visible frame \(visible)")
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
