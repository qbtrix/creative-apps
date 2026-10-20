// SuiteJourneyTests+Transform.swift: the gallery's `transform-handles` page
// (packet docs/blueprints/suiteui/features/transform-tools.md, Journey steps
// 1 to 5; written in TT-2, turned on by TT-4). From the index it opens the
// page: a 200 × 120 box with its eight handles and the rotate knob, the
// transform rows beside it. It drags the knob a quarter turn, the right handle
// 40 pt along the turned edge, clicks Flip Horizontal, then types 15 in the
// rotation row and Shift-drags the knob. The page's log (`suite.gallery.log`)
// names each command it ran.
import XCTest

final class SuiteTransformJourneyTests: XCTestCase {
    /// False until TT-4 turns the journey on: the rows are a placeholder and the page runs no commands yet.
    private static let built = false

    /// The row's value as the rows read it out (`suite.transform.<row>`).
    @MainActor private static func value(_ gallery: Journey, _ row: String) -> String {
        let element = gallery.element("suite.transform.\(row)")
        return (element.value as? String) ?? element.label
    }

    /// TT-3 and TT-4: the box turns with its knob, grows in its own frame, mirrors in place, and snaps under Shift.
    @MainActor func testTransformHandlesTurnAndFlip() throws {
        guard Self.built else { throw XCTSkip("waits on TT-4") }
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")

        // 1. Open the page: the box, its eight handles and the knob; the rows read the box.
        gallery.element("suite.gallery.index.transform-handles").click()
        XCTAssert(gallery.element("suite.gallery.transform-handles").waitForExistence(timeout: 10),
                  "no root suite.gallery.transform-handles")
        for name in ["topLeft", "top", "topRight", "right", "bottomRight", "bottom", "bottomLeft", "left", "rotate"] {
            XCTAssert(gallery.element("suite.handles.\(name)").exists, "no handle \(name)")
        }
        XCTAssertEqual(["x", "y", "w", "h", "rotation"].map { Self.value(gallery, $0) }, ["100", "80", "200", "120", "0°"])
        gallery.shot("transform-open")

        // 2. A quarter turn clockwise on the knob: 90°, one transform.rotate per sample under one drag token.
        let knob = gallery.element("suite.handles.rotate"), box = gallery.element("suite.gallery.transform-box")
        let centre = box.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: centre.withOffset(CGVector(dx: 120, dy: 0)))
        XCTAssertEqual(Self.value(gallery, "rotation"), "90°")
        let log = gallery.element("suite.gallery.log").label
        XCTAssert(log.contains("transform.rotate") && !log.contains("transform.set"), "the knob drag ran \(log)")
        gallery.shot("transform-turned")

        // 3. The right handle, now at the bottom, 40 pt along the turned edge: W 240, the opposite edge stays.
        let right = gallery.element("suite.handles.right").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        right.press(forDuration: 0.1, thenDragTo: right.withOffset(CGVector(dx: 0, dy: 40)))
        XCTAssertEqual(Self.value(gallery, "w"), "240")
        gallery.shot("transform-grown")

        // 4. Flip Horizontal: the turn reads -90°; the log names one transform.flip.
        gallery.element("suite.transform.flip-horizontal").click()
        XCTAssertEqual(Self.value(gallery, "rotation"), "-90°")
        XCTAssert(gallery.element("suite.gallery.log").label.contains("transform.flip"), "no transform.flip in the log")
        gallery.shot("transform-flipped")

        // 5. Type 15 in the rotation row, then Shift-drag the knob: it lands on a 15° step.
        let rotation = gallery.element("suite.transform.rotation")
        rotation.doubleClick()
        rotation.typeText("15\r")
        XCTAssertEqual(Self.value(gallery, "rotation"), "15°")
        XCUIElement.perform(withKeyModifiers: .shift) {
            knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: centre.withOffset(CGVector(dx: 100, dy: 37)))
        }
        let degrees = Double(Self.value(gallery, "rotation").replacingOccurrences(of: "°", with: "")) ?? 1
        XCTAssertEqual(degrees.truncatingRemainder(dividingBy: 15), 0, "the Shift-drag didn't snap to 15°")
        XCTAssertEqual(knob.label, "Rotate, \(Int(degrees)) degrees")
        gallery.shot("transform-snapped")
    }
}
