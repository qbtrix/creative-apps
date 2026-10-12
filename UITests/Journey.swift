// Journey.swift: the shared steps of the human-like UI tests. Every
// <X>JourneyTests target compiles this file next to its own journey file.
//
// A Journey launches the release bundle scripts/bundle-apps wrote to
// .build/apps/<X>App.app (the apps stay SwiftPM targets; no Xcode app target
// builds them), clicks through it like a person would, and after every step
// attaches a screenshot named "<app>-<step>" that outlives a passing run.
// scripts/ui-test exports those as .build/ui-screens/<app>-<step>.png, so keep
// each step name unique within an app.
//
// It finds the window shell by SuiteUI's accessibility identifiers
// (`suite.sidebar`, `suite.inspector`, the `suite.tools` palette) and
// everything else by the titles a person reads: button labels, menu names.
// The first failed step stops the test, so later shots never show a wrong state.
import XCTest

@MainActor
struct Journey {
    let app: XCUIApplication
    private let name: String
    private let test: XCTestCase

    /// Launches `.build/apps/<appName>App.app` fresh, with no restored windows.
    init(_ appName: String, _ test: XCTestCase) {
        // This file is UITests/Journey.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        app = XCUIApplication(url: root.appending(path: ".build/apps/\(appName)App.app"))
        name = appName.lowercased()
        self.test = test
        test.continueAfterFailure = false
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.activate()
    }

    /// Attaches the whole window as "<app>-<step>"; `screen` takes the whole
    /// screen instead, for a menu that hangs outside the window.
    func shot(_ step: String, screen: Bool = false) {
        let image = screen ? XCUIScreen.main.screenshot() : app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = "\(name)-\(step)"
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }

    /// The window is up with its sidebar, inspector and toolbar; shoots "launch".
    func expectWindowShell() {
        XCTAssert(app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(element("suite.sidebar").waitForExistence(timeout: 5), "no sidebar (suite.sidebar)")
        XCTAssert(element("suite.inspector").exists, "no inspector (suite.inspector)")
        XCTAssert(app.toolbars.firstMatch.exists, "no window toolbar")
        shot("launch")
    }

    /// Where a button sits in the window.
    enum Place { case content, toolbar, sheet }

    /// Clicks the button titled `title` in `place`; shoots `step` when given one.
    func click(_ title: String, in place: Place = .content, step: String? = nil) {
        let buttons = switch place {
        case .content: app.splitGroups.buttons
        case .toolbar: app.toolbars.buttons
        case .sheet: app.sheets.buttons
        }
        let button = buttons[title].firstMatch
        XCTAssert(button.waitForExistence(timeout: 10), "no button titled \(title) in the \(place)")
        button.click()
        if let step { shot(step) }
    }

    /// Goes through the canvas palette in order and shoots "tool-<title>" for
    /// each tool: an enabled tool gets clicked; a disabled one (it can't act
    /// yet) gets hovered, so the shot shows the tooltip saying why.
    func clickEachTool() {
        let tools = element("suite.tools").buttons
        XCTAssert(tools.firstMatch.waitForExistence(timeout: 10), "no tool palette (suite.tools)")
        for index in 0..<tools.count {
            let tool = tools.element(boundBy: index)
            let title = tool.label
            if tool.isEnabled {
                tool.click()
            } else {
                tool.hover()
                // ponytail: fixed wait for the system tooltip delay; no query sees tooltips.
                Thread.sleep(forTimeInterval: 2)
            }
            shot("tool-\(slug(title))")
        }
    }

    /// Opens every menu in the menu bar but the Apple menu, shoots "menu-<title>"
    /// with it open, and closes it again.
    func openEachMenu() {
        let menus = app.menuBars.firstMatch.menuBarItems
        XCTAssert(menus.firstMatch.waitForExistence(timeout: 10), "no menu bar")
        // Index 0 is the Apple menu, which belongs to the system, not the app.
        for index in 1..<menus.count {
            let menu = menus.element(boundBy: index)
            let title = menu.title
            menu.click()
            shot("menu-\(slug(title))", screen: true)
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// "New Composition…" becomes "new-composition".
    private func slug(_ title: String) -> String {
        title.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: "-")
    }
}
