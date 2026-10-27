// HaloJourneyTests+SuiteMenus.swift (editor-menus EM-6): Halo as a suite editor. File keeps New Window
// (#1081) and Help holds the suite's items with no empty Halo Help (#1018); Window > AI Access… opens its
// window, and its close button closes it; Window > Switch To lists Home and the five apps, and clicking Home
// brings the AfterGlow launcher forward; a live `afterglow` call reaches the open project; and with every
// window closed by its close button, a Dock click opens a new one. Halo runs from inside
// .build/apps/AfterGlow.app, as a user's does, so Switch To finds the launcher. A step XCUITest can't drive
// here is skipped with its reason; the skips are thrown together at the end, so every other step still runs.
import AppKit
import XCTest

final class HaloSuiteMenusJourneyTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    private static let bundle = root.appending(path: ".build/apps/AfterGlow.app/Contents/Helpers/Halo.app")
    private static let launcher = "org.creativesuite.afterglow"
    private var skips: [String] = []

    @MainActor func testSuiteMenus() throws {
        let support = FileManager.default.temporaryDirectory.appending(path: "halo-suite-menus-\(UUID().uuidString)")
        addTeardownBlock { @MainActor in
            XCUIApplication(bundleIdentifier: Self.launcher).terminate()
            try? FileManager.default.removeItem(at: support)
        }
        try JourneyLive.grant("halo", in: support)
        let halo = Journey("Halo", self, arguments: ["-HaloWindowSize", "1000x640", "-SuiteSupportDir", support.path],
                           bundle: Self.bundle)
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 10), "Halo opened no window")
        let file = titles(of: "File", in: halo)
        XCTAssert(file.contains("New Window"), "File lost New Window (#1081): \(file)")
        let help = titles(of: "Help", in: halo, shot: "suite-menus-help")
        XCTAssertFalse(help.contains("Halo Help"), "Help still holds the system's empty Halo Help (#1018): \(help)")
        XCTAssert(help.contains("Report a Problem…") && help.contains("Beta Notes"), "Help lacks the suite's items: \(help)")
        openAIAccess(in: halo)
        switchHome(from: halo)
        attempt("live") { try liveReachesProject(halo) }
        reopenFromDock(halo)
        if !skips.isEmpty { throw XCTSkip(skips.joined(separator: "; ")) }
    }

    @MainActor private func attempt(_ name: String, _ body: () throws -> Void) {
        do { try body() } catch let skip as XCTSkip {
            skips.append("\(name): \(skip.message ?? "skipped")")
        } catch {
            XCTFail("\(name): \(error)")
        }
    }

    /// The titles of `menu`'s top-level items, read with the menu open; shot as `shot` when given one.
    @MainActor private func titles(of menu: String, in halo: Journey, shot: String? = nil) -> [String] {
        let bar = halo.app.menuBars.firstMatch.menuBarItems[menu]
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(menu) menu")
        bar.click()
        let items = bar.menus.firstMatch.children(matching: .menuItem)
        _ = items.firstMatch.waitForExistence(timeout: 3)
        let found = items.allElementsBoundByIndex.map(\.title).filter { !$0.isEmpty }
        if let shot { halo.shot(shot, screen: true) }
        halo.press(.escape)
        return found
    }

    /// Window > AI Access… opens the AI Access window; its close button closes it.
    @MainActor private func openAIAccess(in halo: Journey) {
        let window = halo.app.menuBars.firstMatch.menuBarItems["Window"]
        window.click()
        let item = window.menuItems["AI Access…"]
        XCTAssert(item.waitForExistence(timeout: 3), "Window holds no AI Access…")
        item.click()
        let access = halo.app.windows["AI Access"]
        XCTAssert(access.waitForExistence(timeout: 5), "AI Access… opened no window")
        halo.shot("suite-menus-ai-access")
        let close = access.buttons[XCUIIdentifierCloseWindow]
        XCTAssert(close.waitForExistence(timeout: 3), "the AI Access window has no close button")
        close.click()
        XCTAssert(access.waitForNonExistence(timeout: 5), "the AI Access close button left the window open")
    }

    /// Window > Switch To lists Home and the other four apps enabled, and Halo's own row; clicking Home
    /// brings the launcher forward.
    @MainActor private func switchHome(from halo: Journey) {
        halo.app.activate()
        let window = halo.app.menuBars.firstMatch.menuBarItems["Window"]
        window.click()
        let switchTo = window.menuItems["Switch To"]
        XCTAssert(switchTo.waitForExistence(timeout: 3), "Window has no Switch To")
        switchTo.hover()
        let home = switchTo.menuItems["Home"]
        XCTAssert(home.waitForExistence(timeout: 3), "Switch To has no Home")
        halo.shot("menu-window-switch-to", screen: true)
        XCTAssert(switchTo.menuItems["Show Halo Window"].exists, "Switch To has no row for Halo itself")
        for title in ["Home", "Flare", "Design", "Photo", "Library"] {
            XCTAssert(switchTo.menuItems[title].exists && switchTo.menuItems[title].isEnabled, "Switch To's \(title) is missing or disabled")
        }
        home.click()
        let until = Date().addingTimeInterval(15)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Self.launcher, Date() < until {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(NSWorkspace.shared.frontmostApplication?.bundleIdentifier, Self.launcher, "clicking Home didn't bring the launcher forward")
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.launcher).forEach { $0.terminate() }
        halo.app.activate()
    }

    /// A granted client's `composition.new` over the live socket lands in the front window: the reply names
    /// its undo step, Edit's Undo item now names it too, and the new composition shows; shot as `suite-menus-live`.
    @MainActor private func liveReachesProject(_ halo: Journey) throws {
        halo.app.activate()
        let before = JourneyLive.undoTitle(in: halo)
        let result = try JourneyLive.run("halo", "composition.new", params: ["name": "Live Comp"])
        let step = result["undoStep"] as? String ?? ""
        XCTAssertFalse(step.isEmpty, "the live call named no undo step: \(result)")
        let named = NSPredicate(format: "label == %@ OR value == %@ OR title == %@", "Live Comp", "Live Comp", "Live Comp")
        let shown = halo.app.descendants(matching: .any).matching(named).firstMatch.waitForExistence(timeout: 5)
        let after = JourneyLive.undoTitle(in: halo)
        halo.shot("suite-menus-live")
        XCTAssert(shown, "the live call's composition doesn't show in the window")
        XCTAssertNotEqual(after, before, "the live call left Edit's Undo at \(before): the project didn't change")
        XCTAssertEqual(after, "Undo \(step)", "Edit's Undo doesn't name the live call's step")
    }

    /// Closes every window by its close button, answering Don't Save if a window asks; then opens the
    /// running bundle again, which hands it the same reopen event a Dock click does: a fresh window opens.
    @MainActor private func reopenFromDock(_ halo: Journey) {
        halo.app.activate()
        for _ in 0..<6 where halo.app.windows.count > 0 {
            let sheet = halo.app.sheets.firstMatch
            if sheet.exists {
                halo.shot("suite-menus-close-prompt")
                sheet.buttons["Don't Save"].click()
            } else {
                halo.app.windows.firstMatch.buttons[XCUIIdentifierCloseWindow].click()
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        if halo.app.windows.count > 0 {
            halo.shot("suite-menus-left-open")
            XCTFail("the close buttons left windows open: \(halo.app.windows.allElementsBoundByIndex.map(\.title))")
            return
        }
        NSWorkspace.shared.openApplication(at: Self.bundle, configuration: NSWorkspace.OpenConfiguration())
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 10), "the Dock reopen opened no window")
        halo.shot("suite-menus-reopened")
    }
}
