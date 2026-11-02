// FlareJourneyTests+SuiteMenus.swift (editor-menus EM-5): Flare as a suite editor. Help holds the suite's
// items with no empty Flare Help; Window > AI Access… opens its window, and its close button closes it;
// Window > Switch To lists Home and the five apps, and clicking Home brings the AfterGlow launcher forward;
// a live `afterglow` call from a client granted in the support folder reaches the open sample (#4808); and with every window closed by its close button, a
// Dock click opens a new one. Flare runs from inside .build/apps/AfterGlow.app, as a user's does, so Switch
// To finds the launcher. A step XCUITest can't drive here is skipped with its reason, and the skips are
// thrown together at the end, so the steps that can run always do.
import AppKit
import XCTest

final class FlareSuiteMenusJourneyTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let bundle = root.appending(path: ".build/apps/AfterGlow.app/Contents/Helpers/Flare.app")
    private static let launcher = "org.creativesuite.afterglow"
    private var skipped: [String] = []

    @MainActor func testSuiteMenus() throws {
        let support = FileManager.default.temporaryDirectory.appending(path: "flare-suite-menus-\(UUID().uuidString)")
        addTeardownBlock { @MainActor in
            XCUIApplication(bundleIdentifier: Self.launcher).terminate()
            try? FileManager.default.removeItem(at: support)
        }
        try JourneyLive.grant("flare", in: support)
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce", "-SuiteSupportDir", support.path], bundle: Self.bundle)
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 10), "Flare opened no window")
        helpHoldsSuiteItems(flare)
        aiAccessOpens(flare)
        switchToReachesHome(flare)
        step("live") { try liveReachesDocument(flare) }
        dockReopens(flare)
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }

    @MainActor private func step(_ name: String, _ body: () throws -> Void) {
        do { try body() } catch let skip as XCTSkip {
            skipped.append("\(name): \(skip.message ?? "skipped")")
        } catch {
            XCTFail("\(name): \(error)")
        }
    }

    /// Help holds Report a Problem… and Beta Notes, and not the system's empty Flare Help; shot open.
    @MainActor private func helpHoldsSuiteItems(_ flare: Journey) {
        let bar = flare.app.menuBars.firstMatch.menuBarItems["Help"]
        XCTAssert(bar.waitForExistence(timeout: 5), "no Help menu")
        bar.click()
        let items = bar.menus.firstMatch.children(matching: .menuItem)
        _ = items.firstMatch.waitForExistence(timeout: 3)
        let help = items.allElementsBoundByIndex.map(\.title).filter { !$0.isEmpty }
        flare.shot("suite-menus-help", screen: true)
        flare.press(.escape)
        XCTAssertFalse(help.contains("Flare Help"), "Help still holds the system's empty Flare Help: \(help)")
        XCTAssert(help.contains("Report a Problem…") && help.contains("Beta Notes"), "Help lacks the suite's items: \(help)")
    }

    /// Window > AI Access… opens the AI Access window; its close button closes it.
    @MainActor private func aiAccessOpens(_ flare: Journey) {
        let window = flare.app.menuBars.firstMatch.menuBarItems["Window"]
        XCTAssert(window.waitForExistence(timeout: 5), "no Window menu")
        window.click()
        let item = window.menuItems["AI Access…"]
        XCTAssert(item.waitForExistence(timeout: 3), "Window holds no AI Access…")
        item.click()
        let access = flare.app.windows["AI Access"]
        XCTAssert(access.waitForExistence(timeout: 5), "AI Access… opened no window")
        flare.shot("suite-menus-ai-access")
        let close = access.buttons[XCUIIdentifierCloseWindow]
        XCTAssert(close.waitForExistence(timeout: 3), "the AI Access window has no close button")
        close.click()
        XCTAssert(access.waitForNonExistence(timeout: 5), "the AI Access close button left the window open")
    }

    /// Window > Switch To lists Home and the other four apps enabled, and Flare's own row; clicking Home
    /// brings the launcher forward.
    @MainActor private func switchToReachesHome(_ flare: Journey) {
        flare.app.activate()
        let window = flare.app.menuBars.firstMatch.menuBarItems["Window"]
        window.click()
        let switchTo = window.menuItems["Switch To"]
        XCTAssert(switchTo.waitForExistence(timeout: 3), "Window has no Switch To")
        switchTo.hover()
        let home = switchTo.menuItems["Home"]
        XCTAssert(home.waitForExistence(timeout: 3), "Switch To has no Home")
        flare.shot("menu-window-switch-to", screen: true)
        XCTAssert(switchTo.menuItems["Show Flare Window"].exists, "Switch To has no row for Flare itself")
        for title in ["Home", "Design", "Photo", "Library", "Halo"] {
            XCTAssert(switchTo.menuItems[title].exists && switchTo.menuItems[title].isEnabled, "Switch To's \(title) is missing or disabled")
        }
        home.click()
        let deadline = Date().addingTimeInterval(15)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Self.launcher, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.bundleIdentifier, Self.launcher, "clicking Home didn't bring the launcher forward")
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.launcher).forEach { $0.terminate() }
        flare.app.activate()
    }

    /// A granted client's `timeline.insert-frames` over the live socket lands in the front window: the reply
    /// names its undo step, and Edit's Undo item now names it too; shot as `suite-menus-live`.
    @MainActor private func liveReachesDocument(_ flare: Journey) throws {
        flare.app.activate()
        let before = JourneyLive.undoTitle(in: flare)
        let result = try JourneyLive.run("flare", "timeline.insert-frames", params: ["count": 1])
        let step = result["undoStep"] as? String ?? ""
        XCTAssertFalse(step.isEmpty, "the live call named no undo step: \(result)")
        let deadline = Date().addingTimeInterval(5)
        var after = JourneyLive.undoTitle(in: flare)
        while after == before, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.3)
            after = JourneyLive.undoTitle(in: flare)
        }
        flare.shot("suite-menus-live")
        XCTAssertNotEqual(after, before, "the live call left Edit's Undo at \(before): the document didn't change")
        XCTAssertEqual(after, "Undo \(step)", "Edit's Undo doesn't name the live call's step")
    }

    /// Closes every window by its close button, answering Don't Save if a window asks; then opens the
    /// running bundle again, which sends it the reopen event a Dock click sends: a new window opens.
    @MainActor private func dockReopens(_ flare: Journey) {
        flare.app.activate()
        for _ in 0..<6 where flare.app.windows.count > 0 {
            let sheet = flare.app.sheets.firstMatch
            if sheet.exists {
                flare.shot("suite-menus-close-prompt")
                sheet.buttons["Don't Save"].click()
            } else {
                flare.app.windows.firstMatch.buttons[XCUIIdentifierCloseWindow].click()
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        if flare.app.windows.count > 0 {
            flare.shot("suite-menus-left-open")
            let titles = flare.app.windows.allElementsBoundByIndex.map(\.title)
            XCTFail("the close buttons left windows open: \(titles)")
            return
        }
        NSWorkspace.shared.openApplication(at: Self.bundle, configuration: NSWorkspace.OpenConfiguration())
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 10), "the Dock reopen opened no window")
        flare.shot("suite-menus-reopened")
    }
}
