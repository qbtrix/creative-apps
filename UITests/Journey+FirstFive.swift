// Journey+FirstFive.swift: the shared steps of the "first five minutes" beta
// gate. Each <X>JourneyTests+FirstFiveMinutes.swift does that app's top three
// first-week tasks the way a new user would, one test per task: a fresh launch
// with an empty suite store (`FirstFive.freshProfile`, so no recents), every
// control found by what is on screen (the menu bar, the toolbar, a visible
// button or tool), no keyboard shortcuts and no context menus. Typing words
// into a field and Return to finish them are allowed; ⌘-anything is not.
//
// Findability: each task's entry point is checked first. `reachable(menu:)`
// opens a menu bar item (click 1), hovers any submenu on the way and returns
// the item (click 2); `reachable(_:)` returns a visible button (click 1). Both
// fail unless the entry is shown, enabled and named in plain words
// (`FirstFive.isPlain`: a few words, no identifier or symbol name). Shots
// go through `snap`, unaudited, so the gate fails only on the tasks.
//
// System panels (Open, Save) are the system's, not ours: a journey checks the
// button that opens one and then lets the app's launch argument
// (-PhotoOpenFile, -LibraryImportFolder, -<X>ExportTo, ...) stand in for the
// pick. A task that can't be done fails with a message naming its `finding`
// issue, and `timeBox()` fails a task that takes over five minutes. Foundation,
// ImageIO and XCTest only: every journey bundle compiles this file.
import ImageIO
import XCTest

enum FirstFive {
    /// The wall-clock budget of one task.
    static let budget: TimeInterval = 300

    /// A fresh empty folder under the temporary directory.
    static func folder(_ prefix: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "\(prefix)-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Launch flags for an empty suite store: no recents, nothing remembered.
    static func freshProfile() -> [String] {
        ["-SuiteSupportDir", folder("first5-support").path]
    }

    /// A label a new user reads as words: one to five words, each with a
    /// letter, none an identifier (`flare.export`, `toggle_key`, `autoKey`).
    static func isPlain(_ label: String) -> Bool {
        let words = label.split(separator: " ")
        guard (1...5).contains(words.count) else { return false }
        return label.contains(where: \.isLetter) && words.allSatisfy { word in
            !word.contains("_")
                && word.range(of: "[a-z]\\.[a-z]|[a-z][A-Z]", options: .regularExpression) == nil
        }
    }

    /// The first file in `folder` with extension `ext` within `timeout` seconds.
    static func file(in folder: URL, ext: String, timeout: TimeInterval = 60) -> URL? {
        let deadline = Date(timeIntervalSinceNow: timeout)
        repeat {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
            if let name = names.sorted().first(where: { $0.lowercased().hasSuffix("." + ext) }) {
                return folder.appending(path: name)
            }
            Thread.sleep(forTimeInterval: 0.5)
        } while Date() < deadline
        return nil
    }

    /// The pixel size ImageIO reads from the image at `url`.
    static func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (width, height)
    }

    /// Polls `condition` for up to `seconds`.
    static func wait(_ seconds: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.25)
        } while Date() < deadline
        return condition()
    }
}

extension Journey {
    /// Fails the test at teardown when it ran past `FirstFive.budget`.
    func timeBox() {
        let start = Date()
        nonisolated(unsafe) let test = test
        test.executionTimeAllowance = FirstFive.budget
        test.addTeardownBlock { @MainActor () async -> Void in
            let spent = Date().timeIntervalSince(start)
            XCTAssertLessThanOrEqual(spent, FirstFive.budget, "\(test.name) took \(Int(spent)) s, over five minutes")
        }
    }

    /// Attaches the window as "<app>-<step>" without auditing it: this gate
    /// judges the tasks, and the app audit has its own journeys and baseline.
    func snap(_ step: String) {
        shot(step, element: app.windows.firstMatch, audit: false)
    }

    /// The menu item at `path` (menu bar item, any submenus, the item), with
    /// the menu left open: shown, enabled and in plain words, so a new user
    /// gets there in two clicks. `stuck` names the finding when it fails.
    @discardableResult
    func reachable(menu path: [String], stuck: String = "") -> XCUIElement {
        let where_ = path.joined(separator: " > ")
        var item = app.menuBars.firstMatch.menuBarItems[path.first ?? ""]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(path.first ?? "") menu \(stuck)")
        item.click()
        for (depth, title) in path.dropFirst().enumerated() {
            if depth > 0 { item.hover() }
            item = item.menus.firstMatch.children(matching: .menuItem)[title]
            XCTAssert(item.waitForExistence(timeout: 3), "a new user can't find \(where_) \(stuck)")
        }
        XCTAssert(item.isEnabled, "\(where_) is disabled \(stuck)")
        XCTAssert(path.allSatisfy(FirstFive.isPlain), "\(where_) isn't in plain words \(stuck)")
        return item
    }

    /// Clicks the menu item at `path` after the findability check.
    func choose(menu path: [String], stuck: String = "") {
        reachable(menu: path, stuck: stuck).click()
    }

    /// The window's button a person reads as `title` (or `title…`): visible,
    /// enabled and in plain words, one click away. `in` narrows it to a part
    /// of the window, such as the tool palette.
    @discardableResult
    func reachable(_ title: String, in root: XCUIElement? = nil, stuck: String = "") -> XCUIElement {
        let scope = root ?? app.windows.firstMatch
        let button = scope.buttons.matching(NSPredicate(
            format: "label ==[c] %@ OR label ==[c] %@ OR title ==[c] %@", title, title + "…", title)).firstMatch
        XCTAssert(button.waitForExistence(timeout: 10), "a new user sees no \(title) button \(stuck)")
        XCTAssert(button.isHittable, "\(title) isn't on screen \(stuck)")
        XCTAssert(FirstFive.wait(5) { button.isEnabled }, "\(title) is disabled \(stuck)")
        XCTAssert(FirstFive.isPlain(button.label), "\(title) reads \(button.label), not plain words \(stuck)")
        return button
    }
}
