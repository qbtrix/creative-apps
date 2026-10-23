// FlareJourneyTests+SuiteMenus.swift (editor-menus EM-5): Flare as a suite editor. Window > AI Access… opens
// its window; Control-Command-0 brings Home (the AfterGlow launcher) forward; a live `afterglow` call reaches
// the open document; and with the last window closed, a Dock click opens a new one. A step XCUITest can't
// drive here is skipped with its reason, and the skips are thrown together at the end, so the steps that can
// run always do.
import AppKit
import XCTest

final class FlareSuiteMenusJourneyTests: XCTestCase {
    private var skipped: [String] = []

    @MainActor func testSuiteMenus() throws {
        let flare = Journey("Flare", self)
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 10), "Flare opened no window")
        aiAccessOpens(flare)
        step("Home") { try self.homeComesForward(flare) }
        step("live") { throw XCTSkip("the journey has no afterglow client to call Flare's live socket and answer its approval sheet") }
        step("reopen") { try self.dockReopens(flare) }
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }

    @MainActor private func step(_ name: String, _ body: () throws -> Void) {
        do { try body() } catch let skip as XCTSkip {
            skipped.append("\(name): \(skip.message ?? "skipped")")
        } catch {
            XCTFail("\(name): \(error)")
        }
    }

    /// Window > AI Access… opens the AI Access window.
    @MainActor private func aiAccessOpens(_ flare: Journey) {
        let window = flare.app.menuBars.firstMatch.menuBarItems["Window"]
        XCTAssert(window.waitForExistence(timeout: 5), "no Window menu")
        window.click()
        let item = window.menuItems["AI Access…"]
        XCTAssert(item.waitForExistence(timeout: 3), "Window holds no AI Access…")
        item.click()
        XCTAssert(flare.app.windows["AI Access"].waitForExistence(timeout: 5), "AI Access… opened no window")
        flare.shot("suite-menus-ai-access")
        flare.press(character: "w", .command)
    }

    /// Control-Command-0 brings the launcher forward. The journey runs Flare from .build/apps, outside an
    /// AfterGlow.app, so when no launcher answers the step is skipped (AfterGlowJourneyTests covers Home).
    @MainActor private func homeComesForward(_ flare: Journey) throws {
        flare.app.activate()
        flare.press(character: "0", [.control, .command])
        let launcher = "org.creativesuite.afterglow"
        let deadline = Date().addingTimeInterval(5)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != launcher {
            guard Date() < deadline else {
                throw XCTSkip("Control-Command-0 brought no launcher forward: Flare runs from .build/apps with no AfterGlow.app beside it")
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        NSRunningApplication.runningApplications(withBundleIdentifier: launcher).forEach { $0.terminate() }
        flare.app.activate()
    }

    /// Closes every window, then opens the running bundle again, which sends it the reopen event a Dock
    /// click sends; a new window opens.
    @MainActor private func dockReopens(_ flare: Journey) throws {
        flare.app.activate()
        var closing = 0
        while flare.app.windows.count > 0, closing < 5 {
            flare.press(character: "w", .command)
            closing += 1
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard flare.app.windows.count == 0 else { throw XCTSkip("Command-W left a window open, so there was no last window to close") }
        guard let bundle = bundleURL() else { throw XCTSkip("no Flare bundle to send the reopen event to") }
        NSWorkspace.shared.openApplication(at: bundle, configuration: NSWorkspace.OpenConfiguration())
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 10), "the Dock reopen opened no window")
        flare.shot("suite-menus-reopened")
    }

    /// `.build/apps/FlareApp.app`, which Journey launched.
    private func bundleURL() -> URL? {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let url = root.appending(path: ".build/apps/FlareApp.app")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
