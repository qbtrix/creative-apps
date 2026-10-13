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
// (`suite.sidebar`, `suite.inspector`, the `suite.tools` palette, the
// `suite.canvas` of an editor shell) and everything else by the titles a
// person reads: button labels, menu names. Launch arguments let a journey skip
// system panels (Photo's `-PhotoOpenFile` and `-PhotoExportTo`).
// The first failed step stops the test, so later shots never show a wrong state.
// Every window shot is also audited (Audit.swift); an audit failure doesn't
// stop the journey. The class's last test (in run order, which is by name)
// must launch a Journey: its teardown closes the app's audit tally.
import XCTest

@MainActor
struct Journey {
    let app: XCUIApplication
    let name: String
    let test: XCTestCase

    /// Launches `.build/apps/<appName>App.app` fresh, with no restored windows
    /// and `arguments` added to its launch arguments.
    init(_ appName: String, _ test: XCTestCase, arguments: [String] = []) {
        // This file is UITests/Journey.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        app = XCUIApplication(url: root.appending(path: ".build/apps/\(appName)App.app"))
        name = appName.lowercased()
        self.test = test
        test.continueAfterFailure = false
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"] + arguments
        app.launch()
        app.activate()
        if test.name == type(of: test).defaultTestSuite.tests.last?.name {
            nonisolated(unsafe) let journey = self
            test.addTeardownBlock { @MainActor () async -> Void in journey.auditLower() }
        }
    }

    /// Attaches the whole window as "<app>-<step>" and audits it; `screen`
    /// takes the whole screen instead, for a menu that hangs outside the
    /// window, and skips the audit (the menu covers the window's pixels).
    func shot(_ step: String, screen: Bool = false) {
        let image = screen ? XCUIScreen.main.screenshot() : app.windows.firstMatch.screenshot()
        let attachment = XCTAttachment(screenshot: image)
        attachment.name = "\(name)-\(step)"
        attachment.lifetime = .keepAlways
        test.add(attachment)
        if !screen { audit(step) }
    }

    /// The window is up with its sidebar, inspector and toolbar; shoots "launch".
    func expectWindowShell() {
        XCTAssert(app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(element("suite.sidebar").waitForExistence(timeout: 5), "no sidebar (suite.sidebar)")
        XCTAssert(element("suite.inspector").exists, "no inspector (suite.inspector)")
        XCTAssert(app.toolbars.firstMatch.exists, "no window toolbar")
        shot("launch")
    }

    /// The editor shell is up with its tool rail, canvas area and right
    /// panel; shoots "launch".
    func expectEditorShell() {
        XCTAssert(app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(element("suite.tools").waitForExistence(timeout: 5), "no tool rail (suite.tools)")
        XCTAssert(element("suite.inspector").exists, "no right panel (suite.inspector)")
        shot("launch")
    }

    /// Where a button sits: a split view's content, the toolbar, a sheet, or
    /// anywhere in the window (an editor shell has no split view).
    enum Place { case content, toolbar, sheet, window }

    /// Clicks the button titled `title` in `place`; shoots `step` when given one.
    func click(_ title: String, in place: Place = .content, step: String? = nil) {
        let buttons = switch place {
        case .content: app.splitGroups.buttons
        case .toolbar: app.toolbars.buttons
        case .sheet: app.sheets.buttons
        case .window: app.windows.firstMatch.buttons
        }
        let button = buttons[title].firstMatch
        XCTAssert(button.waitForExistence(timeout: 10), "no button titled \(title) in the \(place)")
        button.click()
        if let step { shot(step) }
    }

    /// Shoots the canvas palette as "tools", then clicks each enabled tool in
    /// order and shoots "tool-<title>". A disabled tool (it can't act yet)
    /// shows only in "tools"; it gets clicked once it is enabled.
    func clickEachTool() {
        let tools = element("suite.tools").buttons
        XCTAssert(tools.firstMatch.waitForExistence(timeout: 10), "no tool palette (suite.tools)")
        shot("tools")
        for index in 0..<tools.count {
            let tool = tools.element(boundBy: index)
            guard tool.isEnabled else { continue }
            let title = tool.label
            tool.click()
            shot("tool-\(slug(title))")
        }
    }

    /// Opens every menu in the menu bar but the Apple menu, checks it really
    /// opened (and, for a menu named in `expecting`, that it shows that item),
    /// shoots "menu-<title>" with it open, and closes it again.
    func openEachMenu(expecting: [String: String] = [:]) {
        let menus = app.menuBars.firstMatch.menuBarItems
        XCTAssert(menus.firstMatch.waitForExistence(timeout: 10), "no menu bar")
        // Index 0 is the Apple menu, which belongs to the system, not the app.
        for index in 1..<menus.count {
            let menu = menus.element(boundBy: index)
            let title = menu.title
            menu.click()
            // A click that lands while the last menu is still closing can leave this one shut.
            if !isShowing(menu) { menu.click() }
            XCTAssert(isShowing(menu), "the \(title) menu didn't open")
            if let item = expecting[title] {
                XCTAssert(menu.menuItems[item].isHittable, "the \(title) menu shows no \(item)")
            }
            shot("menu-\(slug(title))", screen: true)
            app.typeKey(.escape, modifierFlags: [])
        }
    }

    /// Whether `menu` is open: its first item is on screen, checked for up to three seconds.
    private func isShowing(_ menu: XCUIElement) -> Bool {
        let item = menu.menuItems.firstMatch
        for _ in 0..<10 {
            if item.exists, item.isHittable { return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return false
    }

    /// Drags across the element `identifier` between two points given as
    /// fractions of its size; shoots `step` when given one.
    func drag(on identifier: String, from start: CGVector, to end: CGVector, step: String? = nil) {
        let target = element(identifier)
        XCTAssert(target.waitForExistence(timeout: 10), "no \(identifier) to drag on")
        target.coordinate(withNormalizedOffset: start)
            .press(forDuration: 0.1, thenDragTo: target.coordinate(withNormalizedOffset: end))
        if let step { shot(step) }
    }

    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// "New Composition…" becomes "new-composition".
    private func slug(_ title: String) -> String {
        title.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: "-")
    }
}
