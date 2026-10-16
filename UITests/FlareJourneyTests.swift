// FlareJourneyTests.swift: Flare driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Flare's features land, and replace the skipped
// test with the real journey when its issue is built. The easing journey
// (docs/blueprints/flare-easing-editor.md) starts from File > New Sample
// Animation and checks every step by the active preset chip and by where the
// curve well draws handle 1.
import XCTest

final class FlareJourneyTests: XCTestCase {
    /// J0: the window is SuiteWindow with the empty state's New Animation and
    /// the toolbar's eight actions, each found by its title.
    @MainActor func testLaunchShowsWindowShell() {
        let flare = Journey("Flare", self)
        flare.expectWindowShell()
        XCTAssert(
            flare.app.splitGroups.buttons["New Animation"].waitForExistence(timeout: 10),
            "the empty state has no New Animation")
        let toolbar = flare.app.toolbars.firstMatch
        XCTAssert(toolbar.buttons["Open"].exists, "the toolbar has no Open")
        for title in ["New", "Open", "Save", "Undo", "Redo", "Auto-key", "Animate…", "Export…"] {
            XCTAssert(toolbar.buttons[title].exists, "the toolbar has no \(title)")
        }
    }

    @MainActor func testNewAnimationAndEveryTool() {
        let flare = Journey("Flare", self)
        flare.click("New Animation", step: "new-animation")
        flare.clickEachTool()
    }

    @MainActor func testEveryMenuOpens() {
        let flare = Journey("Flare", self)
        flare.click("New Animation")
        flare.openEachMenu()
    }

    @MainActor func testDrawKeyAndSave() throws {
        throw XCTSkip("journey arrives with #203 (draw), #204 (key) and #205 (save)")
    }

    @MainActor func testEditEasingOfAKeyframeSegment() {
        let flare = Journey("Flare", self)
        flare.app.menuBars.menuBarItems["File"].click()
        let sample = flare.app.menuBars.menuItems["New Sample Animation"]
        XCTAssert(sample.waitForExistence(timeout: 5), "File has no New Sample Animation")
        sample.click()
        flare.shot("easing-sample")
        for row in ["x 0 → 24", "x 24 → 48", "y 0 → 24"] {
            XCTAssert(flare.app.buttons[row].waitForExistence(timeout: 10), "KEYFRAMES doesn't list \(row)")
        }
        XCTAssert(flare.app.staticTexts["Pick a keyframe above."].exists, "no hint to pick a keyframe")

        // On the runner's 1024-wide screen the inspector fits only with the
        // sidebar hidden (View > Hide Sidebar, by its shortcut). The app keeps
        // that across launches, so it is shown again however the test ends.
        flare.app.typeKey("s", modifierFlags: [.control, .command])
        nonisolated(unsafe) let app = flare.app
        addTeardownBlock { @MainActor () async -> Void in
            let show = app.buttons["Show Sidebar"]
            if show.exists { show.click() }
        }

        flare.click("x 0 → 24", in: .window, step: "easing-segment")
        XCTAssert(flare.app.buttons["x 0 → 24"].isSelected, "x 0 → 24 isn't selected")
        XCTAssertEqual(activePreset(flare), "Linear", "the sample's segment isn't linear")

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
