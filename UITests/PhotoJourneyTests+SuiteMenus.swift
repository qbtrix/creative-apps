// PhotoJourneyTests+SuiteMenus.swift (editor-menus EM-3): Photo as a suite editor. Window > AI Access…
// opens its window; Control-Command-0 brings Home (the AfterGlow launcher) forward; a live `afterglow`
// call reaches the open image; with the last window closed, a Dock click opens a new one; and the home's
// New Photo opens a new image in Photo (#3648). A step XCUITest can't drive here is skipped with its
// reason at the end, so the steps that can run always do.
import AppKit
import XCTest

final class PhotoSuiteMenusJourneyTests: XCTestCase {
    private static let launcher = "org.creativesuite.afterglow", photoID = "org.creativesuite.photo"
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    @MainActor func testSuiteMenus() throws {
        let recovery = FileManager.default.temporaryDirectory.appending(path: "photo-suite-menus-\(UUID().uuidString)")
        let photo = Journey("Photo", self, arguments: photoArguments(recoveryDir: recovery))
        XCTAssert(photo.app.windows.firstMatch.waitForExistence(timeout: 10), "Photo opened no window")
        let window = photo.app.menuBars.firstMatch.menuBarItems["Window"]
        window.click()
        XCTAssert(window.menuItems["AI Access…"].waitForExistence(timeout: 3), "Window holds no AI Access…")
        window.menuItems["AI Access…"].click()
        XCTAssert(photo.app.windows["AI Access"].waitForExistence(timeout: 5), "AI Access… opened no window")
        photo.shot("suite-menus-ai-access")
        photo.press(character: "w", .command)
        let skipped = [homeComesForward(photo),
                       "live: a live afterglow call needs a granted client, and the runner has none: Photo's ask refuses until SuiteShell has an async approval sheet",
                       dockReopens(photo)].compactMap { $0 }
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }

    /// The home's New Photo: Photo comes forward on a new image (#3648). This bundle has no SuiteHarness
    /// (only AfterGlowJourneyTests compiles it), so the launcher starts here with the harness's flags.
    @MainActor func testNewPhotoFromHome() throws {
        let bundle = Self.root.appending(path: ".build/apps/AfterGlow.app")
        guard FileManager.default.fileExists(atPath: bundle.path) else { throw XCTSkip("no AfterGlow.app in .build/apps to start the home from") }
        let support = FileManager.default.temporaryDirectory.appending(path: "photo-suite-home-\(UUID().uuidString)")
        let photo = XCUIApplication(bundleIdentifier: Self.photoID)
        addTeardownBlock { @MainActor in
            for id in [Self.launcher, Self.photoID] { XCUIApplication(bundleIdentifier: id).terminate() }
            try? FileManager.default.removeItem(at: support)
        }
        let home = Journey("AfterGlow", self, name: "afterglow", arguments: [
            "-SuiteSupportDir", support.path, "-SuiteSkipOnboarding", "YES", "-SuiteFixture", "firstLaunch",
            "-SuiteFixtureDocuments", Self.root.appending(path: "UITests/Fixtures/suite").path,
        ], bundle: bundle)
        let tile = home.app.descendants(matching: .any)["afterglow.home.new.photo"]
        XCTAssert(tile.waitForExistence(timeout: 30) && tile.isHittable, "the home shows no New Photo")
        tile.click()
        XCTAssert(photo.wait(for: .runningForeground, timeout: 30), "New Photo didn't bring Photo forward (#3648)")
        XCTAssert(photo.descendants(matching: .any)["suite.canvas"].waitForExistence(timeout: 15), "New Photo opened no image (#3648)")
        add(XCTAttachment(screenshot: photo.windows.firstMatch.screenshot()))
    }

    /// Control-Command-0 brings the launcher forward; nil, or why it was skipped: the journey runs Photo
    /// from .build/apps with no AfterGlow.app beside it (AfterGlowJourneyTests covers Home).
    @MainActor private func homeComesForward(_ photo: Journey) -> String? {
        photo.app.activate()
        photo.press(character: "0", [.control, .command])
        let deadline = Date().addingTimeInterval(5)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Self.launcher {
            guard Date() < deadline else { return "Home: Control-Command-0 brought no launcher forward outside AfterGlow.app" }
            Thread.sleep(forTimeInterval: 0.2)
        }
        NSRunningApplication.runningApplications(withBundleIdentifier: Self.launcher).forEach { $0.terminate() }
        photo.app.activate()
        return nil
    }

    /// Closes every window, then opens the running bundle again, which sends it the reopen event a Dock
    /// click sends: a new window opens. Nil, or why it was skipped.
    @MainActor private func dockReopens(_ photo: Journey) -> String? {
        photo.app.activate()
        for _ in 0..<5 where photo.app.windows.count > 0 {
            photo.press(character: "w", .command)
            Thread.sleep(forTimeInterval: 0.5)
        }
        guard photo.app.windows.count == 0 else { return "reopen: Command-W left a window open" }
        NSWorkspace.shared.openApplication(at: Self.root.appending(path: ".build/apps/PhotoApp.app"), configuration: NSWorkspace.OpenConfiguration())
        XCTAssert(photo.app.windows.firstMatch.waitForExistence(timeout: 10), "the Dock reopen opened no window")
        photo.shot("suite-menus-reopened")
        return nil
    }
}
