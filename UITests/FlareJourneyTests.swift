// FlareJourneyTests.swift: Flare driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Flare's features land. The whole draw, key, play
// and save loop on live services is J26 (FlareJourneyTests+Loop.swift). The easing journey
// (docs/blueprints/flare-easing-editor.md) starts from File > Open Sample >
// Keyed Ball (FlareJourneyTests+Menus.swift, with J1) and checks every step by the active preset chip and by where the
// curve well draws handle 1. On the 1024 x 768 runner the window, its
// columns, the timeline and the easing rows must fit the screen with the
// sidebar showing (`expectEasingGeometry`, #1841), the inspector is the
// editor panel's width and every preset chip's title fits its chip (#1853,
// #1847); the nudge goes to the X1 row, which takes the arrow keys once a
// click has given it focus.
import AppKit
import XCTest

final class FlareJourneyTests: XCTestCase {
    /// The toolbar's eight actions: intent identifier, title, and the reason
    /// its area gives while no document is open (nil: enabled).
    static let toolbar: [(id: String, title: String, reason: String?)] = [
        ("flare.file.new", "New", nil), ("flare.file.open", "Open", nil),
        ("flare.file.save", "Save", "Open or create an animation first."), ("flare.edit.undo", "Undo", "Nothing to undo."),
        ("flare.edit.redo", "Redo", "Nothing to redo."),
        ("flare.timeline.toggleAutoKey", "Auto-key", "Open an animation to key it."),
        ("flare.assist.showPopover", "Animate…", "Not built yet (F16a)."),
        ("flare.export.showSheet", "Export…", "Not built yet (F15a)."),
    ]

    /// J0: the window is SuiteWindow with the empty state's New Animation and
    /// the toolbar's eight actions, each identified by its FlareIntent and,
    /// while disabled, saying its area's reason in `suite.controls`. Every
    /// control goes through the router: selecting Ball in the sidebar selects
    /// it, and Auto-key reads selected after a click.
    @MainActor func testLaunchShowsWindowShell() {
        let flare = Journey("Flare", self, arguments: ["-SuitePerfProbe"])
        flare.expectWindowShell()
        XCTAssert(
            flare.app.splitGroups.buttons["New Animation"].waitForExistence(timeout: 10),
            "the empty state has no New Animation")
        let toolbar = flare.app.toolbars.firstMatch
        for action in Self.toolbar {
            let button = toolbar.buttons[action.id]
            XCTAssert(button.exists, "the toolbar has no \(action.title) identified \(action.id)")
            XCTAssertEqual(button.label, action.title, "\(action.id) isn't titled \(action.title)")
            XCTAssertEqual(button.isEnabled, action.reason == nil, "\(action.id) is enabled wrongly")
        }
        var entries: [String: ControlEntry] = [:]
        for _ in 0..<10 where Self.toolbar.contains(where: { entries[$0.id] == nil }) {
            entries = Dictionary((flare.controls()?.controls ?? []).map { ($0.id, $0) }) { first, _ in first }
            Thread.sleep(forTimeInterval: 0.2)
        }
        for action in Self.toolbar {
            XCTAssertEqual(entries[action.id]?.reason, action.reason, "\(action.id)'s tooltip isn't its area's help")
        }

        // The sidebar goes through `.layers` intents: Scene 1 drops the layer
        // selection (the easing editor hides), and Ball brings it back.
        flare.openSample("Keyed Ball")
        let hint = flare.app.staticTexts["Pick a keyframe above."]
        XCTAssert(hint.waitForExistence(timeout: 10), "the sample didn't open with Ball selected")
        let sidebar = flare.element("suite.sidebar")
        sidebar.staticTexts["Scene 1"].click()
        XCTAssert(hint.waitForNonExistence(timeout: 5), "selecting Scene 1 kept Ball selected")
        sidebar.staticTexts["Ball"].click()
        XCTAssert(hint.waitForExistence(timeout: 5), "selecting Ball in the sidebar didn't select it")
        flare.shot("sidebar-ball")

        let autoKey = toolbar.buttons["flare.timeline.toggleAutoKey"]
        XCTAssert(autoKey.isEnabled, "Auto-key is disabled with the sample open")
        autoKey.click()
        flare.shot("auto-key")
        // SuiteWindow's toolbar draws no selected state yet (needs-ui #1621).
        XCTExpectFailure("SuiteWindow drops ToolbarAction.isSelected (#1621)", options: .nonStrict()) {
            XCTAssert(autoKey.isSelected, "Auto-key doesn't read selected after a click")
        }
    }

    @MainActor func testNewAnimationAndEveryTool() {
        let flare = Journey("Flare", self)
        flare.click("New Animation", step: "new-animation")
        flare.clickEachTool()
    }

    @MainActor func testEditEasingOfAKeyframeSegment() {
        let flare = Journey("Flare", self, arguments: ["-SuiteWindowSize", "1024x768"])
        flare.openSample("Keyed Ball")
        flare.shot("easing-sample")
        let rows = [
            ("x frames 0 → 24", "x.0-24"), ("x frames 24 → 48", "x.24-48"), ("y frames 0 → 24", "y.0-24"),
        ]
        for (row, id) in rows {
            XCTAssert(flare.app.buttons[row].waitForExistence(timeout: 10), "KEYFRAMES doesn't list \(row)")
            XCTAssertEqual(
                flare.app.buttons[row].identifier, "flare.easing.segment.\(id)", "\(row) has no stable identifier")
        }
        XCTAssert(flare.app.staticTexts["Pick a keyframe above."].exists, "no hint to pick a keyframe")

        flare.click("x frames 0 → 24", in: .window, step: "easing-segment")
        XCTAssert(flare.app.buttons["x frames 0 → 24"].isSelected, "x frames 0 → 24 isn't selected")
        XCTAssertEqual(activePreset(flare), "Linear", "the sample's segment isn't linear")
        expectEasingGeometry(flare)
        scrollInspector(toShow: flare.element("flare.easing"), flare)
        expectPresetsFit(flare)

        flare.click("Ease In", in: .window, step: "easing-preset")
        XCTAssertEqual(activePreset(flare), "Ease In", "Ease In isn't the active preset")
        expectHandle(1, at: CGPoint(x: 0.42, y: 0), flare, "Ease In's handle 1 isn't at (0.42, 0)")
        let second = flare.element("flare.easing.handle2").frame

        let well = flare.element("flare.easing")
        XCTAssert(well.waitForExistence(timeout: 10), "no easing curve (flare.easing)")
        let frame = well.frame
        func at(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            well.coordinate(withNormalizedOffset: .zero).withOffset(
                CGVector(dx: 12 + x * (frame.width - 24), dy: 12 + (1.25 - y) / 1.5 * (frame.height - 24)))
        }
        at(0.42, 0).press(forDuration: 0.2, thenDragTo: at(0.25, 0.45))
        flare.shot("easing-drag")
        XCTAssertNil(activePreset(flare), "a preset is still active after the drag")
        expectHandle(1, at: CGPoint(x: 0.25, y: 0.45), flare, "handle 1 didn't follow the drag", accuracy: 0.03)
        XCTAssertEqual(flare.element("flare.easing.handle2").frame, second, "the drag moved handle 2")
        let dragged = handle(1, flare)

        // A click on X1 opens its typing field and Escape closes it unchanged,
        // leaving the row the keys: each Right press steps x by 0.01.
        let x1 = flare.element("flare.easing.row.x1")
        scrollInspector(toShow: x1, flare)
        x1.click()
        flare.press(.escape)
        for _ in 0..<5 { flare.app.typeKey(.rightArrow, modifierFlags: []) }
        flare.shot("easing-nudge")
        expectHandle(1, at: CGPoint(x: dragged.x + 0.05, y: dragged.y), flare, "five Right presses didn't add 0.05 to x")

        // Five nudges and one drag are six undo steps, each named for the edit.
        for undo in 1...6 {
            let edit = flare.app.menuBars.menuBarItems["Edit"]
            edit.click()
            let item = flare.app.menuBars.menuItems["Undo Set Keyframe Easing"]
            if !item.waitForExistence(timeout: 5) {
                let titles = edit.menuItems.allElementsBoundByIndex.map(\.title)
                XCTFail("Edit > Undo isn't named Undo Set Keyframe Easing: \(titles)")
            }
            if undo == 1 { flare.shot("easing-undo-menu", screen: true) }
            item.click()
        }
        flare.shot("easing-undo")
        XCTAssertEqual(activePreset(flare), "Ease In", "six undos didn't bring back Ease In")
        expectHandle(1, at: CGPoint(x: 0.42, y: 0), flare, "six undos didn't put handle 1 back")
    }

    /// The window fits the display's visible frame with the sidebar showing;
    /// the sidebar, the timeline, the inspector, the toolbar and the curve
    /// sit inside the window, the three columns don't overlap, the timeline
    /// shows its ruler and a lane, and scrolling the inspector brings each
    /// easing row (X1 to Y2) inside it at its full height (#1841).
    @MainActor private func expectEasingGeometry(_ flare: Journey) {
        let window = flare.app.windows.firstMatch.frame
        let screens = NSScreen.screens
        let top = screens.first?.frame.height ?? 0
        let display = screens.map { screen -> CGRect in
            let visible = screen.visibleFrame
            return CGRect(x: visible.minX, y: top - visible.maxY, width: visible.width, height: visible.height)
        }
        XCTAssert(
            display.contains { $0.insetBy(dx: -1, dy: -1).contains(window) },
            "the window \(window) runs off the display's visible frame \(display)")
        var regions: [String: AppAudit.Rect] = [:]
        for id in ["suite.sidebar", "suite.inspector", "flare.timeline", "flare.easing"] {
            let region = flare.element(id)
            XCTAssert(region.waitForExistence(timeout: 5), "no \(id)")
            regions[id] = rect(region.frame)
        }
        regions["toolbar"] = rect(flare.app.toolbars.firstMatch.frame)
        let minimums: [String: (width: Double, height: Double)] = [
            "suite.sidebar": (width: 1, height: 1), "suite.inspector": (width: Self.inspectorWidth, height: 1),
            "flare.timeline": (width: 1, height: 56), "flare.easing": (width: 1, height: 1),
            "toolbar": (width: 1, height: 1),
        ]
        let apart = [
            ("suite.sidebar", "flare.timeline"), ("suite.sidebar", "suite.inspector"), ("flare.timeline", "suite.inspector"),
        ]
        let found = ShellGeometry.violations(
            window: rect(window), regions: regions, minimums: minimums, apart: apart, clear: [])
        XCTAssert(found.isEmpty, "Flare's easing window geometry:\n" + found.joined(separator: "\n"))
        for row in ["x1", "y1", "x2", "y2"] {
            let element = flare.element("flare.easing.row.\(row)")
            scrollInspector(toShow: element, flare)
            XCTAssert(window.contains(element.frame), "\(row) \(element.frame) is outside the window \(window)")
            XCTAssert(element.frame.height >= 20, "\(row) is only \(element.frame.height) pt tall")
        }
        flare.shot("easing-geometry")
    }

    /// FlareWindow.inspectorWidth: SuiteSize.editorPanelWidth (280) plus
    /// SuiteSpacing.m (12) on each side (#1853).
    static let inspectorWidth = 304.0

    /// Each preset chip is at least as wide as its title drawn in the chip's
    /// font (caption, semibold) plus its 4 pt side padding, so no title is
    /// cut to "Ease…" (#1847, #1853).
    @MainActor private func expectPresetsFit(_ flare: Journey) {
        let font = NSFont.systemFont(ofSize: NSFont.preferredFont(forTextStyle: .caption1).pointSize, weight: .semibold)
        for title in ["Linear", "Ease", "Ease In", "Ease Out", "Ease In-Out", "Hold"] {
            let chip = flare.app.windows.firstMatch.buttons[title]
            XCTAssert(chip.waitForExistence(timeout: 5), "no \(title) preset")
            let needed = (title as NSString).size(withAttributes: [.font: font]).width + 2 * 4
            XCTAssert(chip.frame.width >= needed, "\(title) is \(chip.frame.width) pt wide, its title needs \(needed)")
        }
    }

    /// Scrolls the inspector until `element` is inside it.
    @MainActor private func scrollInspector(toShow element: XCUIElement, _ flare: Journey) {
        let inspector = flare.element("suite.inspector")
        XCTAssert(element.waitForExistence(timeout: 5), "nothing to scroll to in the inspector")
        for _ in 0..<20 where !inspector.frame.contains(element.frame) {
            inspector.scroll(byDeltaX: 0, deltaY: element.frame.minY < inspector.frame.minY ? 40 : -40)
        }
        XCTAssert(
            inspector.frame.contains(element.frame), "scrolling didn't bring \(element.frame) into \(inspector.frame)")
    }

    private func rect(_ frame: CGRect) -> AppAudit.Rect {
        AppAudit.Rect(x: Double(frame.minX), y: Double(frame.minY), width: Double(frame.width), height: Double(frame.height))
    }

    /// The preset chip shown as active, or nil when none is. Exact, unlike a
    /// handle's position: a chip is active only when the curve equals it.
    @MainActor private func activePreset(_ journey: Journey) -> String? {
        ["Linear", "Ease", "Ease In", "Ease Out", "Ease In-Out", "Hold"]
            .first { journey.app.windows.firstMatch.buttons[$0].isSelected }
    }

    /// Handle `n` in unit space, read from where the well draws it: the well
    /// insets its plot by 12 pt and, for these curves, shows y from -0.25 to
    /// 1.25 (CurveEditor.plotRange). The rows' values can't be read here: on
    /// macOS XCUITest gets an empty value from them.
    @MainActor private func handle(_ n: Int, _ journey: Journey) -> CGPoint {
        let well = journey.element("flare.easing").frame
        let dot = journey.element("flare.easing.handle\(n)").frame
        return CGPoint(
            x: (dot.midX - well.minX - 12) / (well.width - 24),
            y: 1.25 - (dot.midY - well.minY - 12) / (well.height - 24) * 1.5)
    }

    @MainActor private func expectHandle(
        _ n: Int, at want: CGPoint, _ journey: Journey, _ message: String, accuracy: CGFloat = 0.015
    ) {
        let got = handle(n, journey)
        XCTAssertEqual(got.x, want.x, accuracy: accuracy, "\(message): \(got)")
        XCTAssertEqual(got.y, want.y, accuracy: accuracy, "\(message): \(got)")
    }
}
