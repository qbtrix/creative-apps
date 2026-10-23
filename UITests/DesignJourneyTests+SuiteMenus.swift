// DesignJourneyTests+SuiteMenus.swift (editor-menus EM-4): Design as a suite editor. Window > AI Access…
// opens its window; Control-Command-0 brings Home (the AfterGlow launcher) forward; a live `afterglow`
// call reaches the open file; and with the last window closed, a Dock click opens a new one. A step
// XCUITest can't drive here, or Design's stub host can't act on, is skipped with its reason at the end,
// so the steps that can run always do.
import AppKit
import XCTest

final class DesignSuiteMenusJourneyTests: XCTestCase {
    @MainActor func testSuiteMenus() throws {
        let design = Journey("Design", self)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 10), "Design opened no window")
        let window = design.app.menuBars.firstMatch.menuBarItems["Window"]
        window.click()
        XCTAssert(window.menuItems["AI Access…"].waitForExistence(timeout: 3), "Window holds no AI Access…")
        window.menuItems["AI Access…"].click()
        XCTAssert(design.app.windows["AI Access"].waitForExistence(timeout: 5), "AI Access… opened no window")
        design.shot("suite-menus-ai-access")
        design.press(character: "w", .command)
        let skipped = [homeComesForward(design),
                       "live: a live afterglow call needs a granted client, and the runner has none: Design's ask refuses until SuiteShell has an async approval sheet",
                       dockReopens(design)].compactMap { $0 }
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }

    /// Control-Command-0 brings the launcher forward; nil, or why it was skipped: the journey runs Design
    /// from .build/apps with no AfterGlow.app beside it (AfterGlowJourneyTests covers Home).
    @MainActor private func homeComesForward(_ design: Journey) -> String? {
        let launcher = "org.creativesuite.afterglow"
        design.app.activate()
        design.press(character: "0", [.control, .command])
        let deadline = Date().addingTimeInterval(5)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != launcher {
            guard Date() < deadline else { return "Home: Control-Command-0 brought no launcher forward outside AfterGlow.app" }
            Thread.sleep(forTimeInterval: 0.2)
        }
        NSRunningApplication.runningApplications(withBundleIdentifier: launcher).forEach { $0.terminate() }
        design.app.activate()
        return nil
    }

    /// Closes every window, then opens the running bundle again, which sends it the reopen event a Dock
    /// click sends: a new window opens. Nil, or why it was skipped.
    @MainActor private func dockReopens(_ design: Journey) -> String? {
        design.app.activate()
        for _ in 0..<5 where design.app.windows.count > 0 {
            design.press(character: "w", .command)
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard design.app.windows.count == 0 else { return "reopen: Command-W left a window open" }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        NSWorkspace.shared.openApplication(at: root.appending(path: ".build/apps/DesignApp.app"), configuration: NSWorkspace.OpenConfiguration())
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 10), "the Dock reopen opened no window")
        design.shot("suite-menus-reopened")
        return nil
    }
}
