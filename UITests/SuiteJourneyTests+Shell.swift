// SuiteJourneyTests+Shell.swift: the gallery's `shell` page (AppKit window shell
// spike, slice 0) in Library. The journey helper finds the AppKit sidebar,
// canvas and inspector and the two toolbar toggles by their identifiers, shoots
// the launch in Light and Dark, and clicks each toggle away and back. The
// collapsed item is hidden, so its element goes away or reads zero width.
import XCTest

extension SuiteJourneyTests {
    static let shellLaunch = ["-SuiteGallery", "shell", "-SuiteWindowSize", "1024x768", "-SuitePerfProbe"]
    static let shellParts = ["suite.sidebar", "suite.canvas", "suite.inspector", "suite.sidebarToggle", "suite.inspectorToggle"]

    /// Light (forced through NSRequiresAquaSystemAppearance, so a dark Mac shoots it light too): every part by
    /// identifier, then each toggle hides and shows its panel.
    @MainActor func testShellPagePartsAndToggles() {
        let light = ["-NSRequiresAquaSystemAppearance", "YES"] + Self.shellLaunch
        let gallery = Journey("Library", self, name: "suiteui", arguments: light)
        XCTAssert(gallery.element("suite.gallery.shell").waitForExistence(timeout: 30), "no shell page")
        for id in Self.shellParts {
            XCTAssert(gallery.element(id).waitForExistence(timeout: 10), "the journey helper finds no \(id)")
        }
        gallery.shot("shell-launch")

        gallery.element("suite.inspectorToggle").click()
        XCTAssert(shellWait { self.shellHidden(gallery.element("suite.inspector")) }, "the inspector toggle left the inspector up")
        gallery.shot("shell-inspector-hidden")
        gallery.element("suite.inspectorToggle").click()
        XCTAssert(shellWait { !self.shellHidden(gallery.element("suite.inspector")) }, "the inspector didn't come back")

        gallery.element("suite.sidebarToggle").click()
        XCTAssert(shellWait { self.shellHidden(gallery.element("suite.sidebar")) }, "the sidebar toggle left the sidebar up")
        gallery.shot("shell-sidebar-hidden")
        gallery.element("suite.sidebarToggle").click()
        XCTAssert(shellWait { !self.shellHidden(gallery.element("suite.sidebar")) }, "the sidebar didn't come back")
    }

    /// Dark: the launch shot. The appearance pair goes first (SuiteJourneyTests+EditorWindow.swift). The
    /// Light test audits the window; this one only shoots it, so the audit's baseline read happens once per run.
    @MainActor func testShellPageDark() {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-AppleInterfaceStyle", "Dark"] + Self.shellLaunch)
        XCTAssert(gallery.element("suite.gallery.shell").waitForExistence(timeout: 30), "no shell page")
        XCTAssert(gallery.element("suite.sidebar").waitForExistence(timeout: 10), "no sidebar (suite.sidebar)")
        gallery.shot("shell-launch-dark", element: gallery.app.windows.firstMatch, audit: false)
    }

    /// A collapsed split item's view is hidden: its element is gone or has no width.
    @MainActor private func shellHidden(_ element: XCUIElement) -> Bool {
        !element.exists || element.frame.width < 1
    }

    /// `condition` within five seconds, checked every quarter second.
    @MainActor private func shellWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<20 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return condition()
    }
}
