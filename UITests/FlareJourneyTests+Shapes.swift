// FlareJourneyTests+Shapes.swift (shape-tools FS-2; runs from FS-7): the Shape tool driven like a person would. On
// `-FlareSample empty` it presses U, and the inspector's SHAPE section shows the kind chips (suite.shape.chip-<kind>)
// with the star's Points row; it Shift-drags a star (Star 1), keys its rotation at 0 and at 1 s with Auto-key on, then
// picks Arrow and drags an arrow (Arrow 1). Drawing waits on FS-6's addShape and the canvas gesture FS-7 wires, so the
// journey skips until then. One shot per step, `flare-shape-<step>`.
import XCTest

final class FlareShapeJourneyTests: XCTestCase {
    /// True until FS-7 wires the Shape tool's drag to the Model.
    private static let waitsOnFS7 = true

    /// U, a Shift-dragged star keyed at 0 and 1 s, then an arrow: two shape layers.
    @MainActor func testDrawStarAndArrow() throws {
        if Self.waitsOnFS7 { throw XCTSkip("waits on FS-7") }
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "empty"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let stage = flare.element("suite.canvas")
        XCTAssert(stage.waitForExistence(timeout: 10), "no stage (suite.canvas)")
        at(0.95, 0.95, stage).click()

        // 1. U: Shape is the tool and its options show, on a five-point star.
        flare.press(XCUIKeyboardKey(rawValue: "u"), step: "shape-1-tool")
        let shape = flare.element("suite.tools").buttons["Shape"]
        XCTAssert(poll { shape.isSelected }, "U didn't choose Shape")
        for id in ["suite.shape.chip-star", "suite.shape.chip-arrow", "suite.shape.points"] {
            XCTAssert(flare.element(id).waitForExistence(timeout: 5), "the SHAPE section has no \(id)")
        }
        flare.shot("shape-1-options")

        // 2. Shift-drag a star: one layer, Star 1.
        let start = at(0.2, 0.2, stage), side = stage.frame.height * 0.3
        XCUIElement.perform(withKeyModifiers: .shift) {
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: side, dy: side)))
        }
        XCTAssert(poll { named("Star 1", flare) }, "no Star 1 after the drag")
        flare.shot("shape-2-star")

        // 3. Auto-key on; rotation 0 at the first frame, 90 at 1 s: two keys on Star 1's lane.
        flare.app.toolbars.buttons["flare.timeline.toggleAutoKey"].click()
        rotate(to: "0", flare)
        for _ in 0..<24 { flare.press(.rightArrow) }
        rotate(to: "90", flare)
        XCTAssert(poll { named("Rotation", flare) }, "Star 1's rotation isn't keyed")
        flare.shot("shape-3-keyed")

        // 4. Arrow, drag an arrow: Arrow 1 beside Star 1.
        flare.element("suite.shape.chip-arrow").click()
        at(0.6, 0.5, stage).press(forDuration: 0.1, thenDragTo: at(0.9, 0.6, stage))
        XCTAssert(poll { named("Arrow 1", flare) && named("Star 1", flare) }, "no Arrow 1 beside Star 1")
        flare.shot("shape-4-arrow")
    }

    /// Types `value` into the inspector's rotation field and commits it.
    @MainActor private func rotate(to value: String, _ flare: Journey) {
        let field = flare.element("flare.inspector.rotation")
        XCTAssert(field.waitForExistence(timeout: 5), "no rotation row (flare.inspector.rotation)")
        field.doubleClick()
        field.typeText(value + "\r")
    }

    /// Something in the window is labelled `name`.
    @MainActor private func named(_ name: String, _ flare: Journey) -> Bool {
        flare.app.windows.firstMatch.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", name, name)).firstMatch.exists
    }

    /// The point at fractions (`x`, `y`) of `element`.
    @MainActor private func at(_ x: Double, _ y: Double, _ element: XCUIElement) -> XCUICoordinate {
        element.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func poll(_ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(5)
        while Date() < end {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
