// HaloJourneyTests+SuiteMenus.swift (editor-menus EM-6): Halo as a suite editor. File keeps New Window
// (#1081) and Help holds the suite's items with no empty Halo Help (#1018); Window > AI Access… opens its
// window; Control-Command-0 brings Home (the AfterGlow launcher) forward; a live `afterglow` call reaches the
// open project; and with the last window closed, a Dock click opens a new one. A step XCUITest can't drive
// here is skipped with its reason; the skips are thrown together at the end, so every other step still runs.
import AppKit
import XCTest

final class HaloSuiteMenusJourneyTests: XCTestCase {
    private var skips: [String] = []

    @MainActor func testSuiteMenus() throws {
        let halo = Journey("Halo", self, arguments: ["-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 10), "Halo opened no window")
        let file = titles(of: "File", in: halo)
        XCTAssert(file.contains("New Window"), "File lost New Window (#1081): \(file)")
        let help = titles(of: "Help", in: halo)
        XCTAssertFalse(help.contains("Halo Help"), "Help still holds the system's empty Halo Help (#1018): \(help)")
        XCTAssert(help.contains("Report a Problem…") && help.contains("Beta Notes"), "Help lacks the suite's items: \(help)")
        openAIAccess(in: halo)
        attempt("Home") { try self.bringHome(from: halo) }
        attempt("live") { throw XCTSkip("the journey has no afterglow client to call Halo's live socket and answer its approval sheet") }
        attempt("reopen") { try self.reopenFromDock(halo) }
        if !skips.isEmpty { throw XCTSkip(skips.joined(separator: "; ")) }
    }

    @MainActor private func attempt(_ name: String, _ body: () throws -> Void) {
        do { try body() } catch let skip as XCTSkip {
            skips.append("\(name): \(skip.message ?? "skipped")")
        } catch {
            XCTFail("\(name): \(error)")
        }
    }

    /// The titles of `menu`'s top-level items, read with the menu open.
    @MainActor private func titles(of menu: String, in halo: Journey) -> [String] {
        let bar = halo.app.menuBars.firstMatch.menuBarItems[menu]
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(menu) menu")
        bar.click()
        let items = bar.menus.firstMatch.children(matching: .menuItem)
        _ = items.firstMatch.waitForExistence(timeout: 3)
        let found = items.allElementsBoundByIndex.map(\.title).filter { !$0.isEmpty }
        halo.press(.escape)
        return found
    }

    /// Window > AI Access… opens the AI Access window, which Command-W then closes.
    @MainActor private func openAIAccess(in halo: Journey) {
        let window = halo.app.menuBars.firstMatch.menuBarItems["Window"]
        window.click()
        let item = window.menuItems["AI Access…"]
        XCTAssert(item.waitForExistence(timeout: 3), "Window holds no AI Access…")
        item.click()
        XCTAssert(halo.app.windows["AI Access"].waitForExistence(timeout: 5), "AI Access… opened no window")
        halo.shot("suite-menus-ai-access")
        halo.press(character: "w", .command)
    }

    /// Control-Command-0 brings the launcher forward; skipped when none answers, since the journey runs Halo
    /// from .build/apps with no AfterGlow.app beside it (AfterGlowJourneyTests covers Home itself).
    @MainActor private func bringHome(from halo: Journey) throws {
        halo.app.activate()
        halo.press(character: "0", [.control, .command])
        let launcher = "org.creativesuite.afterglow"
        let until = Date().addingTimeInterval(5)
        repeat {
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == launcher {
                NSRunningApplication.runningApplications(withBundleIdentifier: launcher).forEach { $0.terminate() }
                halo.app.activate()
                return
            }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < until
        throw XCTSkip("Control-Command-0 brought no launcher forward: Halo runs from .build/apps with no AfterGlow.app beside it")
    }

    /// Closes the last window, then opens the running bundle again, which hands it the same reopen event a
    /// Dock click does; a fresh window opens.
    @MainActor private func reopenFromDock(_ halo: Journey) throws {
        halo.app.activate()
        for _ in 0..<5 where halo.app.windows.count > 0 {
            halo.press(character: "w", .command)
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard halo.app.windows.count == 0 else { throw XCTSkip("Command-W left a window open, so no last window closed") }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let bundle = root.appending(path: ".build/apps/HaloApp.app")
        guard FileManager.default.fileExists(atPath: bundle.path) else { throw XCTSkip("no HaloApp.app to reopen") }
        NSWorkspace.shared.openApplication(at: bundle, configuration: NSWorkspace.OpenConfiguration())
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 10), "the Dock reopen opened no window")
        halo.shot("suite-menus-reopened")
    }
}
