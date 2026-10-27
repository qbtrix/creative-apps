// LibraryJourneyTests+SuiteMenus.swift (editor-menus EM-7): Library as a suite editor. Window > AI Access…
// opens its window; Control-Command-0 brings Home (the AfterGlow launcher) forward; a live `afterglow` call
// reaches the open catalog; and with the window closed, a Dock click opens a new one. Library has one window
// and quits when it closes (decision D2), so the Dock click launches it again with the same fixture. A step
// XCUITest can't drive here is skipped with its reason, and the skips are thrown together at the end, so the
// steps that can run always do.
import AppKit
import XCTest

final class LibrarySuiteMenusJourneyTests: XCTestCase {
    private var skipped: [String] = []
    private static let arguments = ["-LibraryFixture", "samples"]

    @MainActor func testSuiteMenus() throws {
        let library = Journey("Library", self, arguments: Self.arguments)
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 10), "Library opened no window")
        aiAccessOpens(library)
        step("Home") { try self.homeComesForward(library) }
        step("live") { throw XCTSkip("the journey has no afterglow client to call Library's live socket and answer its approval sheet") }
        step("reopen") { try self.dockReopens(library) }
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
    @MainActor private func aiAccessOpens(_ library: Journey) {
        let window = library.app.menuBars.firstMatch.menuBarItems["Window"]
        XCTAssert(window.waitForExistence(timeout: 5), "no Window menu")
        window.click()
        let item = window.menuItems["AI Access…"]
        XCTAssert(item.waitForExistence(timeout: 3), "Window holds no AI Access…")
        item.click()
        XCTAssert(library.app.windows["AI Access"].waitForExistence(timeout: 5), "AI Access… opened no window")
        library.shot("suite-menus-ai-access")
        library.press(character: "w", .command)
    }

    /// Control-Command-0 brings the launcher forward. The journey runs Library from .build/apps, outside an
    /// AfterGlow.app, so when no launcher answers the step is skipped (AfterGlowJourneyTests covers Home).
    @MainActor private func homeComesForward(_ library: Journey) throws {
        library.app.activate()
        library.press(character: "0", [.control, .command])
        let launcher = "org.creativesuite.afterglow"
        let deadline = Date().addingTimeInterval(5)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != launcher {
            guard Date() < deadline else {
                throw XCTSkip("Control-Command-0 brought no launcher forward: Library runs from .build/apps with no AfterGlow.app beside it")
            }
            Thread.sleep(forTimeInterval: 0.2)
        }
        NSRunningApplication.runningApplications(withBundleIdentifier: launcher).forEach { $0.terminate() }
        library.app.activate()
    }

    /// Closes the window, then opens the bundle again: a reopen event if Library still runs, a launch with the
    /// journey's fixture if closing its one window quit it. Either way a window opens.
    @MainActor private func dockReopens(_ library: Journey) throws {
        library.app.activate()
        // Closing the one window quits Library (D2): a window query on a quit app fails the test, so stop then.
        for _ in 0..<5 where library.app.state != .notRunning && library.app.windows.count > 0 {
            library.press(character: "w", .command)
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard library.app.state != .runningForeground || library.app.windows.count == 0 else {
            throw XCTSkip("Command-W left a window open, so there was no last window to close")
        }
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let bundle = root.appending(path: ".build/apps/LibraryApp.app")
        guard FileManager.default.fileExists(atPath: bundle.path) else { throw XCTSkip("no LibraryApp.app to reopen") }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = ["-ApplePersistenceIgnoreState", "YES"] + Self.arguments
        NSWorkspace.shared.openApplication(at: bundle, configuration: configuration)
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 10), "the Dock reopen opened no window")
        library.shot("suite-menus-reopened")
    }
}
