// FlareJourneyTests+EveryControl.swift: J29 (QB-F1, draw-key-save DK-13), the
// no-dead-controls sweep on `-FlareFixture bounce`. It reads every `flare.*`
// control from `suite.controls` (enabled, and its reason while disabled) and
// clicks each enabled one: the click must change the window shot, a control's
// value or selection, or the control list. After each it presses Escape and
// ⌘Z. A control is judged as the list gives it now, since earlier clicks move
// state Undo doesn't restore; New goes last, as it replaces the document.
// This is a sweep, not feature coverage.
import XCTest

final class FlareControlJourneys: XCTestCase {
    @MainActor func testEveryControlActsOrSaysWhy() {
        let flare = Journey("Flare", self, arguments: ["-FlareFixture", "bounce", "-SuitePerfProbe"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        flare.shot("controls")
        let listed = Self.flareControls(flare)
        XCTAssertFalse(listed.isEmpty, "suite.controls lists no flare control")
        let order = listed.map(\.id).sorted { ($0 == "flare.file.new" ? 1 : 0, $0) < ($1 == "flare.file.new" ? 1 : 0, $1) }
        for id in order {
            guard let entry = Self.flareControls(flare).first(where: { $0.id == id }) else { continue }
            guard entry.enabled else {
                XCTAssertFalse((entry.reason ?? "").isEmpty, "\(id) is disabled and doesn't say why")
                continue
            }
            let control = flare.element(id)
            XCTAssert(control.waitForExistence(timeout: 5), "\(id) is listed but not on screen")
            let before = Self.state(of: control, flare)
            control.click()
            Thread.sleep(forTimeInterval: 0.5)
            let changed = before != Self.state(of: control, flare)
            flare.shot("control-\(flare.slug(id))")
            XCTAssert(changed, "\(id) is enabled but clicking it changed nothing")
            flare.press(.escape)
            flare.press(character: "z", .command)
        }
    }

    /// The `flare.*` entries of `suite.controls` as listed now.
    @MainActor private static func flareControls(_ flare: Journey) -> [ControlEntry] {
        (flare.controls()?.controls ?? []).filter { $0.id.hasPrefix("flare.") }
    }

    /// What a click may change: the window shot, the control's value and
    /// selection, and the control list's JSON.
    @MainActor private static func state(of control: XCUIElement, _ flare: Journey) -> [String] {
        let shot = flare.app.windows.firstMatch.screenshot().pngRepresentation.base64EncodedString()
        let value = control.exists ? "\(control.value ?? "") \(control.isSelected)" : "gone"
        return [shot, value, flare.element("suite.controls").label]
    }
}
