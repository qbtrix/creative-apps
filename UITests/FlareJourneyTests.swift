// FlareJourneyTests.swift: Flare driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Flare's features land, and replace the skipped
// test with the real journey when its issue is built. The easing journey
// (docs/blueprints/flare-easing-editor.md) reads the inspector's X1, Y1, X2
// and Y2 rows after every step (or, if a row exposes no number, the handles'
// values) and finds handle 1 where the curve well draws it, since only the
// well's frame is known to be the shape a person sees.
import XCTest

final class FlareJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Flare", self).expectWindowShell()
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
        flare.click("New Sample Animation", in: .toolbar, step: "easing-sample")
        for row in ["x 0 → 24", "x 24 → 48", "y 0 → 24"] {
            XCTAssert(flare.app.buttons[row].waitForExistence(timeout: 10), "KEYFRAMES doesn't list \(row)")
        }
        XCTAssert(flare.app.staticTexts["Pick a keyframe above."].exists, "no hint to pick a keyframe")

        // On the runner's 1024-wide screen the inspector fits only with the sidebar hidden.
        flare.app.menuBars.menuBarItems["View"].click()
        let hide = flare.app.menuBars.menuItems["Hide Sidebar"]
        XCTAssert(hide.waitForExistence(timeout: 5), "no View > Hide Sidebar")
        hide.click()

        flare.click("x 0 → 24", in: .window, step: "easing-segment")
        XCTAssert(flare.element("flare.easing.row.x1").waitForExistence(timeout: 10), "no X1 row")
        print("easing tree: \(flare.element("flare.easing.row.x1").debugDescription)")
        print("easing tree: \(flare.element("flare.easing").debugDescription)")
        expectRows(flare, [0, 0, 1, 1], "the sample's segment isn't linear")

        flare.click("Ease In", in: .window, step: "easing-preset")
        expectRows(flare, [0.42, 0, 1, 1], "Ease In didn't set its curve")

        // The well insets its plot by 12 pt and, for these handles, shows y
        // from -0.25 to 1.25 (CurveEditor.plotRange), so this maps a unit point.
        let well = flare.element("flare.easing")
        XCTAssert(well.waitForExistence(timeout: 10), "no easing curve (flare.easing)")
        let frame = well.frame
        func at(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
            well.coordinate(withNormalizedOffset: .zero).withOffset(
                CGVector(dx: 12 + x * (frame.width - 24), dy: 12 + (1.25 - y) / 1.5 * (frame.height - 24)))
        }
        at(0.42, 0).press(forDuration: 0.2, thenDragTo: at(0.25, 0.45))
        flare.shot("easing-drag")
        let dragged = rows(flare)
        XCTAssert(dragged[0] < 0.4 && dragged[1] > 0.2, "handle 1 didn't follow the drag up and left: \(dragged)")
        XCTAssertEqual(Array(dragged[2...]), [1, 1], "the drag moved handle 2")

        for _ in 0..<5 { flare.app.typeKey(.rightArrow, modifierFlags: []) }
        flare.shot("easing-nudge")
        let nudged = rows(flare)
        XCTAssertEqual(nudged[0], dragged[0] + 0.05, accuracy: 0.011, "five Right presses didn't add 0.05 to X1")
        XCTAssertEqual(nudged[1], dragged[1], accuracy: 0.005, "Right moved Y1")

        // Five nudges and one drag are six undo steps, each named for the edit.
        for undo in 1...6 {
            flare.app.menuBars.menuBarItems["Edit"].click()
            let item = flare.app.menuBars.menuItems["Undo Set Keyframe Easing"]
            XCTAssert(item.waitForExistence(timeout: 5), "Edit > Undo isn't named Undo Set Keyframe Easing")
            if undo == 1 { flare.shot("easing-undo-menu", screen: true) }
            item.click()
        }
        flare.shot("easing-undo")
        expectRows(flare, [0.42, 0, 1, 1], "six undos didn't bring back Ease In")
    }

    /// X1, Y1, X2 and Y2 as the inspector's rows read them. A row that exposes
    /// no number falls back to its handle's value ("x 0.42, y 0.00"); the raw
    /// values and their types go to the log, so a wrong read shows its cause.
    @MainActor private func rows(_ journey: Journey) -> [Double] {
        [1, 2].flatMap { handle -> [Double] in
            let row = ["x", "y"].map { journey.element("flare.easing.row.\($0)\(handle)").value }
            let point = journey.element("flare.easing.handle\(handle)").value
            print("easing values: rows \(row.map(describe)), handle \(handle) \(describe(point))")
            let fromHandle = numbers(point)
            return (0..<2).map { numbers(row[$0]).first ?? (fromHandle.count == 2 ? fromHandle[$0] : .nan) }
        }
    }

    /// Every number in an accessibility value, whatever type it arrives as.
    private func numbers(_ value: Any?) -> [Double] {
        guard let value else { return [] }
        let text = (value as? NSAttributedString)?.string ?? "\(value)"
        return text.matches(of: #/-?[0-9]+(\.[0-9]+)?/#).compactMap { Double($0.output.0) }
    }

    private func describe(_ value: Any?) -> String {
        value.map { "\($0) (\(type(of: $0)))" } ?? "nil"
    }

    @MainActor private func expectRows(_ journey: Journey, _ want: [Double], _ message: String) {
        let got = rows(journey)
        for (value, expected) in zip(got, want) {
            XCTAssertEqual(value, expected, accuracy: 0.005, "\(message): \(got)")
        }
    }
}
