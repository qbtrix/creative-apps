// SuiteJourneyTests+Transform.swift: the gallery's `transform-handles` page
// (packet docs/blueprints/suiteui/features/transform-tools.md, Journey steps
// 1 to 5; written in TT-2, turned on by TT-4). From the index it opens the
// page: a 200 × 120 box with its eight handles and the rotate knob, the
// transform rows beside it. It drags the knob a quarter turn, the right handle
// 40 pt along the turned edge, clicks Flip Horizontal and Flip Vertical (the
// box stays put), then types 10 in the rotation row and Shift-drags the knob:
// the turn moves by a whole 15° step from 10. A second launch, with keyboard
// navigation on, Tabs through every `suite.transform.*` row and both flips.
// The page's log (`suite.gallery.log`)
// names each command it ran. The rows are sliders, so they read out their
// number ("15"); the knob's turn is the `suite.handles.turn` read-out ("15 degrees"). Steps 2 to 4 assert what
// the page does once TT-5's rules and TT-7's live target land.
import XCTest

final class SuiteTransformJourneyTests: XCTestCase {
    /// The row's number (`suite.transform.<row>`): each row is a slider, so macOS gives its value as a number (#4822).
    @MainActor private static func value(_ gallery: Journey, _ row: String) -> String {
        let element = gallery.element("suite.transform.\(row)")
        // Whole, as the rows show it: the slider reports the raw Double, which a turned resize can leave at 79.99….
        if let number = element.value as? NSNumber { return String(Int(number.doubleValue.rounded())) }
        return (element.value as? String) ?? element.label
    }

    /// X, Y, W and H as the rows read them.
    @MainActor private static func frame(_ gallery: Journey) -> [String] {
        ["x", "y", "w", "h"].map { value(gallery, $0) }
    }

    /// Every row and both flip buttons, the controls a Tab walk must reach.
    private static let tabStops = ["x", "y", "w", "h", "rotation", "flip-horizontal", "flip-vertical"]

    /// Whether any element called `identifier` holds keyboard focus.
    @MainActor private static func focused(_ gallery: Journey, _ identifier: String) -> Bool {
        gallery.app.descendants(matching: .any).matching(identifier: identifier).allElementsBoundByIndex
            .contains { ($0.value(forKey: "hasKeyboardFocus") as? Bool) ?? false }
    }

    /// TT-3 and TT-4: the box turns with its knob, grows in its own frame, mirrors in place, and snaps under Shift.
    @MainActor func testTransformHandlesTurnAndFlip() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")

        // 1. Open the page: the box, its eight handles and the knob; the rows read the box.
        gallery.element("suite.gallery.index.transform-handles").click()
        XCTAssert(gallery.element("suite.gallery.transform-handles").waitForExistence(timeout: 10),
                  "no root suite.gallery.transform-handles")
        for name in ["topLeft", "top", "topRight", "right", "bottomRight", "bottom", "bottomLeft", "left", "rotate"] {
            XCTAssert(gallery.element("suite.handles.\(name)").exists, "no handle \(name)")
        }
        XCTAssertEqual(["x", "y", "w", "h", "rotation"].map { Self.value(gallery, $0) }, ["100", "80", "200", "120", "0"])
        gallery.shot("transform-open")

        // 2. A quarter turn clockwise on the knob: 90°, one transform.rotate per sample under one drag token.
        let knob = gallery.element("suite.handles.rotate"), box = gallery.element("suite.gallery.transform-box")
        let centre = box.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: centre.withOffset(CGVector(dx: 120, dy: 0)))
        XCTAssertEqual(Self.value(gallery, "rotation"), "90")
        let log = gallery.element("suite.gallery.log").label
        XCTAssert(log.contains("transform.rotate") && !log.contains("transform.set"), "the knob drag ran \(log)")
        gallery.shot("transform-turned")

        // 3. The right handle, now at the bottom, 40 pt along the turned edge: W 240, the opposite edge stays.
        // The left edge (at the top once turned) keeps its place, so the centre moves 20 pt down to
        // (200, 160) and the unturned 240 × 120 box sits at X 80, Y 100.
        let right = gallery.element("suite.handles.right").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        right.press(forDuration: 0.1, thenDragTo: right.withOffset(CGVector(dx: 0, dy: 40)))
        XCTAssertEqual(Self.frame(gallery), ["80", "100", "240", "120"], "the turned resize didn't keep the opposite edge")
        gallery.shot("transform-grown")

        // 4. Flip Horizontal: the turn reads -90 degrees, the box doesn't move; the log names one transform.flip.
        gallery.element("suite.transform.flip-horizontal").click()
        XCTAssertEqual(Self.value(gallery, "rotation"), "-90")
        XCTAssertEqual(Self.frame(gallery), ["80", "100", "240", "120"], "Flip Horizontal moved the box")
        XCTAssert(gallery.element("suite.gallery.log").label.contains("transform.flip"), "no transform.flip in the log")
        gallery.shot("transform-flipped")

        // Flip Vertical mirrors it back to 90 degrees, again in place.
        gallery.element("suite.transform.flip-vertical").click()
        XCTAssertEqual(Self.value(gallery, "rotation"), "90")
        XCTAssertEqual(Self.frame(gallery), ["80", "100", "240", "120"], "Flip Vertical moved the box")
        XCTAssert(gallery.element("suite.gallery.log").label.contains("transform.flip"), "no transform.flip in the log")

        // 5. Click the rotation bar, type 10 and press Return, then Shift-drag the knob: the drag adds a whole
        // 15° step (from 10, so a missed snap or no turn at all can't land on one).
        let rotation = gallery.element("suite.transform.rotation")
        let bar = rotation.frame
        rotation.click()
        let fields = gallery.element("suite.gallery.transform-handles").textFields
        let typing = fields.allElementsBoundByIndex.first { $0.frame.midY >= bar.minY && $0.frame.midY <= bar.maxY }
            ?? fields.firstMatch
        XCTAssert(typing.waitForExistence(timeout: 5), "clicking the rotation bar opened no field")
        gallery.press(character: "a", .command)
        typing.typeText("10")
        gallery.press(.return)
        XCTAssertEqual(Self.value(gallery, "rotation"), "10")
        XCUIElement.perform(withKeyModifiers: .shift) {
            knob.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: centre.withOffset(CGVector(dx: 100, dy: 37)))
        }
        let degrees = Double(Self.value(gallery, "rotation")) ?? 1
        XCTAssertNotEqual(degrees, 10, "the Shift-drag didn't turn the box")
        XCTAssertEqual((degrees - 10).truncatingRemainder(dividingBy: 15), 0, "the Shift-drag turned \(degrees - 10)°, not a 15° step")
        let turn = gallery.element("suite.handles.turn")
        XCTAssertEqual(turn.label, "Rotate")
        XCTAssertEqual(turn.value as? String, "\(Int(degrees)) degrees")
        gallery.shot("transform-snapped")
    }

    /// The packet's keyboard row: with keyboard navigation on, Tab reaches every row and both flip buttons.
    @MainActor func testTransformRowsReachableByTab() throws {
        let gallery = Journey("Library", self, name: "suiteui",
                              arguments: ["-SuiteGallery", "transform-handles", "-AppleKeyboardUIMode", "2"])
        XCTAssert(gallery.element("suite.gallery.transform-handles").waitForExistence(timeout: 30),
                  "no root suite.gallery.transform-handles")
        var reached: Set<String> = []
        for _ in 0..<40 where reached.count < Self.tabStops.count {
            gallery.press(.tab)
            reached.formUnion(Self.tabStops.filter { Self.focused(gallery, "suite.transform.\($0)") })
        }
        let missed = Self.tabStops.filter { !reached.contains($0) }
        XCTAssert(missed.isEmpty, "Tab never reached suite.transform.\(missed)")
        gallery.shot("transform-tab")
    }
}
