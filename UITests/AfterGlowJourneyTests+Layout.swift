// AfterGlowJourneyTests+Layout.swift: the home at every width that fits the
// 1024 × 768 runner (packet home.md Journey steps; blueprint suite.md 7.3
// item 3, HM-3b). `testHomeAtEveryWidth` launches on `weekOfWork` through the
// HM-0 harness with `-SuiteWindowSize 880x640` (SuiteSize.windowMinimum's
// width) and `1000x640` (SuiteSize.windowLaunch), shoots `home-880` and
// `home-1000`, and asserts the geometry: the window is the requested width
// within a point, and the sidebar, the New row, the recents grid and the
// running strip each sit inside the window and clear of one another
// (ShellGeometry's `clear` rule, compiled in by project.yml). The home's
// layout anchors (`homeLayoutAnchor`) are SwiftUI preferences read by
// AfterGlowHomeLayoutTests and never reach the accessibility tree, so the New
// row is the union of the five tile buttons (`afterglow.home.new.<app>`), the
// grid the scroll area holding the recent cards (`afterglow.home.card.<id>`;
// the cards' union when no scroll area is exposed) and the strip its
// "No apps running" text. Every shot is audited under `afterglow`
// (UITests/audit-baseline.json: offscreen and overlap at 0), so an element
// outside the window or over another fails the test on its own.
import XCTest

final class AfterGlowLayoutJourneys: XCTestCase {
    /// The widths that fit the runner's display, at the launch height.
    static let widths: [Double] = [880, 1000]
    static let height = 640.0
    /// The recent cards, by their `afterglow.home.card.` identifiers.
    static var cardPredicate: NSPredicate { NSPredicate(format: "identifier BEGINSWITH 'afterglow.home.card.'") }

    @MainActor func testHomeAtEveryWidth() {
        let suite = SuiteHarness(self)
        for width in Self.widths {
            let size = "\(Int(width))x\(Int(Self.height))"
            let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES", "-SuiteWindowSize", size])
            let window = home.app.windows.firstMatch
            XCTAssert(window.waitForExistence(timeout: 30), "AfterGlow opened no window at \(size)")
            XCTAssert(home.element("suite.sidebar").waitForExistence(timeout: 10), "the home at \(size) has no sidebar")
            XCTAssert(Self.cards(home).firstMatch.waitForExistence(timeout: 15), "the home at \(size) shows no recent card")
            XCTAssert(Self.strip(home).waitForExistence(timeout: 5), "the home at \(size) shows no running strip")
            XCTAssert(Self.waitForWidth(window, width), "the window at \(size) is \(window.frame.width) pt wide, not \(width)")
            home.shot("home-\(Int(width))")
            expectGeometry(home, size: size)
        }
    }

    /// The sidebar, New row, recents grid and running strip, each present,
    /// inside the window and clear of the other three.
    @MainActor private func expectGeometry(_ home: Journey, size: String) {
        var regions: [String: AppAudit.Rect] = [:]
        if let sidebar = home.regionFrame("suite.sidebar") { regions["sidebar"] = rect(sidebar) }
        if let tiles = union(SuiteApp.apps.map { home.element("afterglow.home.new.\($0.rawValue)") }) {
            regions["New row"] = rect(tiles)
        }
        let grid = home.app.windows.firstMatch.scrollViews.containing(Self.cardPredicate).firstMatch
        if grid.exists {
            regions["recents grid"] = rect(grid.frame)
        } else if let cards = union(Self.cards(home).allElementsBoundByIndex) {
            regions["recents grid"] = rect(cards)
        }
        let strip = Self.strip(home)
        if strip.exists { regions["running strip"] = rect(strip.frame) }

        let names = ["sidebar", "New row", "recents grid", "running strip"]
        var clear: [(String, String)] = []
        for (index, first) in names.enumerated() {
            for second in names.dropFirst(index + 1) { clear.append((first, second)) }
        }
        let found = ShellGeometry.violations(
            window: rect(home.app.windows.firstMatch.frame), regions: regions,
            minimums: Dictionary(uniqueKeysWithValues: names.map { ($0, (width: 1.0, height: 1.0)) }),
            apart: [], clear: clear)
        XCTAssert(found.isEmpty, "home geometry at \(size):\n" + found.joined(separator: "\n"))
    }

    /// Whether `window` reads `width` wide within a point inside five seconds
    /// (SuiteWindowSizer applies the size on the turn after the window opens).
    @MainActor private static func waitForWidth(_ window: XCUIElement, _ width: Double) -> Bool {
        for _ in 0..<20 {
            if abs(Double(window.frame.width) - width) <= 1 { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return abs(Double(window.frame.width) - width) <= 1
    }

    /// Every recent card on screen.
    @MainActor private static func cards(_ home: Journey) -> XCUIElementQuery {
        home.app.descendants(matching: .any).matching(cardPredicate)
    }

    /// The running strip's value: "No apps running" (a plain Text reads its
    /// words as its value on macOS, so both are matched).
    @MainActor private static func strip(_ home: Journey) -> XCUIElement {
        home.app.staticTexts.matching(
            NSPredicate(format: "label == 'No apps running' OR value == 'No apps running'")).firstMatch
    }

    /// The smallest rectangle around the frames of the `elements` that exist; nil when none does.
    @MainActor private func union(_ elements: [XCUIElement]) -> CGRect? {
        let frames = elements.filter(\.exists).map(\.frame)
        guard let first = frames.first else { return nil }
        return frames.dropFirst().reduce(first) { $0.union($1) }
    }

    private func rect(_ frame: CGRect) -> AppAudit.Rect {
        AppAudit.Rect(x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
    }
}
