// PhotoJourneyTests+Transform.swift: MJ-PT's journey, Free Transform, a turn
// and a flip (transform PT-2 writes it, PT-8 turns it on; docs/blueprints/
// photo/features/transform.md, Journey steps). On beach.png (800 x 600) a
// marquee copied and pasted makes "Pasted Layer", the logo over the photo,
// selected. Edit > Free Transform puts the box (`photo.canvas.transform-box`)
// and its turn knob (`suite.handles.turn`) on the layer's bounds, and the
// inspector shows the transform rows (`suite.transform.x` ... `.rotation`).
// A shift-drag out from the bottom-right handle scales it in proportion; 15
// typed in Rotation turns the box (the knob reads "15 degrees"); Return
// commits one "Free Transform" step and the box goes. Edit > Transform > Flip
// Horizontal is one "Flip Horizontal" step. Image > Canvas Size… (PT-3) with
// Width and Height +400, anchor centre, gives a 1200 x 1000 image. Every step
// shoots `transform-*`. Skipped until PT-8: on PT-2's stubs every edit
// refuses.
import CoreGraphics
import XCTest

final class PhotoTransformJourneyTests: XCTestCase {
    /// MJ-PT: Free Transform, scale, turn 15°, commit, flip, then a canvas border.
    @MainActor func testFreeTransformTurnFlip() throws {
        throw XCTSkip("waits on PT-8")
    }

    /// The journey's steps, which PT-8 runs from `testFreeTransformTurnFlip`.
    @MainActor private func freeTransformTurnFlip() throws {
        let photo = try openBeach()

        // 1. A pasted layer selected, Edit > Free Transform: the box, its knob and the rows.
        photo.element("suite.tools").buttons["Marquee"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.4, dy: 0.4), to: CGVector(dx: 0.6, dy: 0.55))
        photo.press(character: "c", .command)
        photo.press(character: "v", .command)
        XCTAssert(photo.app.staticTexts["Pasted Layer"].waitForExistence(timeout: 5), "the paste made no Pasted Layer")
        photo.press(character: "d", .command)
        choose(["Edit", "Free Transform"], photo)
        let box = photo.element("photo.canvas.transform-box")
        XCTAssert(box.waitForExistence(timeout: 5), "Free Transform put no box on the canvas (photo.canvas.transform-box)")
        XCTAssert(photo.element("suite.handles.turn").waitForExistence(timeout: 5), "the box has no turn knob")
        for row in ["x", "y", "w", "h", "rotation"] {
            XCTAssert(photo.element("suite.transform.\(row)").waitForExistence(timeout: 5), "no transform row \(row)")
        }
        let start = box.frame
        photo.shot("transform-1-begun")

        // 2. Shift-drag the bottom-right handle out: the box grows in proportion.
        let corner = box.coordinate(withNormalizedOffset: CGVector(dx: 1, dy: 1))
        XCUIElement.perform(withKeyModifiers: .shift) {
            corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: 60, dy: 10)))
        }
        let grown = box.frame
        XCTAssertGreaterThan(grown.width, start.width, "the drag didn't scale the box")
        XCTAssertEqual(grown.width / max(grown.height, 1), start.width / max(start.height, 1), accuracy: 0.05,
                       "the shift-drag didn't keep the box's proportions")
        photo.shot("transform-2-scaled")

        // 3. 15 in Rotation: the knob reads 15 degrees.
        let rotation = photo.element("suite.transform.rotation")
        rotation.doubleClick()
        photo.app.typeText("15\r")
        let turned = NSPredicate(format: "value CONTAINS '15 degrees'")
        let knob = photo.element("suite.handles.turn")
        wait(for: [XCTNSPredicateExpectation(predicate: turned, object: knob)], timeout: 5)
        photo.shot("transform-3-turned")

        // 4. Return: one Free Transform step, the box gone.
        photo.element("suite.canvas").click()
        photo.press(.return)
        XCTAssert(box.waitForNonExistence(timeout: 5), "Return left the transform box up")
        XCTAssert(photo.app.buttons["Undo Free Transform"].waitForExistence(timeout: 5), "Return made no Free Transform step")
        photo.shot("transform-4-committed")

        // 5. Edit > Transform > Flip Horizontal: one Flip Horizontal step.
        choose(["Edit", "Transform", "Flip Horizontal"], photo)
        XCTAssert(photo.app.buttons["Undo Flip Horizontal"].waitForExistence(timeout: 5), "the flip made no step")
        photo.shot("transform-5-flipped")

        // 6. Image > Canvas Size…, +400 each way about the centre: 1200 x 1000.
        choose(["Image", "Canvas Size…"], photo)
        let sheet = photo.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 5), "Canvas Size… opened no sheet")
        for field in ["photo.canvas-size.width", "photo.canvas-size.height"] {
            let entry = photo.element(field)
            XCTAssert(entry.waitForExistence(timeout: 5), "the sheet has no \(field)")
            entry.doubleClick()
            photo.app.typeText("400\t")
        }
        sheet.buttons["OK"].click()
        let sized = photo.app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1200 × 1000 px'")).firstMatch
        XCTAssert(sized.waitForExistence(timeout: 5), "the image isn't 1200 × 1000 px after Canvas Size")
        photo.shot("transform-6-border")
    }

    @MainActor private func openBeach() throws -> Journey {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-transform-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "beach.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file))
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "beach.png didn't open")
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        return photo
    }

    /// Opens the menu bar item `path[0]`, hovers each submenu on the way and clicks the last item, which must be on.
    @MainActor private func choose(_ path: [String], _ photo: Journey) {
        var item = photo.app.menuBars.firstMatch.menuBarItems[path.first ?? ""]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(path.first ?? "") menu")
        item.click()
        for (depth, title) in path.dropFirst().enumerated() {
            if depth > 0 { item.hover() }
            item = item.menus.firstMatch.children(matching: .menuItem)[title]
            XCTAssert(item.waitForExistence(timeout: 3), "no \(path.joined(separator: " > "))")
        }
        XCTAssert(item.isEnabled, "\(path.joined(separator: " > ")) is disabled")
        item.click()
    }
}
