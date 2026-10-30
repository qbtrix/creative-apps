// DesignJourneyTests+EveryControl.swift: J15 (design-window DW-c, D0-7b), the
// no-dead-controls sweep on `-DesignFixture cards` with the live services. It
// reads every `design.*` control from `suite.controls` (enabled, and its reason
// while disabled, the "isn't built yet." ones included) and clicks each enabled
// one: the click must change the window shot, the control's value or
// selection, or the control list; asserting the click happened is never
// enough. After each it presses Escape and ⌘Z. A control is judged as the list
// gives it now, since earlier clicks move state Undo doesn't restore. New goes
// last, as it replaces the document. A click that brings up a sheet or dialog
// (Open's panel) is shot as the whole screen, which skips the audit: the panel
// covers the window's controls, which its tree still lists, so a disabled
// button under it measured the panel's ink (#3042). The status line's chips (`design.status.*`)
// are readouts, registered so the audit sees their ids: each must read some
// text instead of acting. Ids registered with `identifies: false` are found by
// the element that carries them on screen (`aliases`). A sweep, not feature
// coverage; FlareJourneyTests+EveryControl.swift is the same shape.
import XCTest

final class DesignEveryControlJourneyTests: XCTestCase {
    /// The element on screen for an id the window registers without identifying its view.
    static let aliases = ["design.canvas.page": "suite.canvas", "design.inspector.fill": "design.fill"]

    @MainActor func testEveryControlActsOrSaysWhy() {
        let design = Journey("Design", self, arguments: ["-DesignFixture", "cards", "-SuitePerfProbe"])
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "cards showed no page")
        design.shot("controls")
        let listed = Self.designControls(design)
        XCTAssertFalse(listed.isEmpty, "suite.controls lists no design control")
        let last = "design.bar.new"
        let order = listed.map(\.id).sorted { ($0 == last ? 1 : 0, $0) < ($1 == last ? 1 : 0, $1) }
        for id in order {
            guard let entry = Self.designControls(design).first(where: { $0.id == id }) else { continue }
            guard entry.enabled else {
                XCTAssertFalse((entry.reason ?? "").isEmpty, "\(id) is disabled and doesn't say why")
                continue
            }
            // A segment already selected (its container's click picked it) has nothing to change.
            guard entry.selected != true else { continue }
            let control = Self.onScreen(id, design)
            XCTAssert(control.waitForExistence(timeout: 5), "\(id) is listed but not on screen")
            if id.hasPrefix("design.status.") {
                XCTAssertFalse(Self.text(control).isEmpty, "the status chip \(id) reads nothing")
                continue
            }
            let before = Self.state(of: control, design)
            control.click()
            Thread.sleep(forTimeInterval: 0.5)
            let changed = before != Self.state(of: control, design)
            design.shot("control-\(design.slug(id))", screen: Self.panelIsUp(design))
            XCTAssert(changed, "\(id) is enabled but clicking it changed nothing")
            design.press(.escape)
            design.press(character: "z", .command)
        }
    }

    /// Whether a sheet or dialog (Open's panel, an alert) covers the window now.
    @MainActor private static func panelIsUp(_ design: Journey) -> Bool {
        design.app.sheets.firstMatch.exists || design.app.dialogs.firstMatch.exists
    }

    /// The `design.*` entries of `suite.controls` as listed now.
    @MainActor private static func designControls(_ design: Journey) -> [ControlEntry] {
        (design.controls()?.controls ?? []).filter { $0.id.hasPrefix("design.") }
    }

    /// The element carrying `id`, or its alias's element when the id identifies no view.
    @MainActor private static func onScreen(_ id: String, _ design: Journey) -> XCUIElement {
        let control = design.element(id)
        guard !control.exists, let alias = aliases[id] else { return control }
        return design.element(alias)
    }

    /// What a click may change: the window shot, the control's value and
    /// selection, and the control list's JSON.
    @MainActor private static func state(of control: XCUIElement, _ design: Journey) -> [String] {
        let shot = design.app.windows.firstMatch.screenshot().pngRepresentation.base64EncodedString()
        let value = control.exists ? "\(control.value ?? "") \(control.isSelected)" : "gone"
        return [shot, value, design.element("suite.controls").label]
    }

    /// What a text reads: its label, or its value where macOS puts a plain Text's words.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }
}
