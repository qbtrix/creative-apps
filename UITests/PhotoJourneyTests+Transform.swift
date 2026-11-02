// PhotoJourneyTests+Transform.swift: MJ-PT's journey, Free Transform, a turn
// and a flip, then a canvas border (transform PT-2 wrote it, PT-8 turns it on
// live; docs/blueprints/photo/features/transform.md, Journey steps). On
// beach.png (800 x 600) a marquee copied and pasted makes "Pasted Layer", the
// logo over the photo, selected; the inspector header reads its line
// "Pasted Layer W × H px at X, Y". Move (V) shows the transform rows
// (`suite.transform.x` ... `.rotation`), and Edit > Free Transform puts the
// box (`photo.canvas.transform-box`) and its turn knob (`suite.handles.turn`)
// on the layer's bounds. A shift-drag out from the bottom-right handle scales
// it in proportion; 15 typed in Rotation turns the box (the knob reads
// "15 degrees"); Return on the canvas commits one "Free Transform" step, the
// box goes and the layer's line changes. Command-Z puts the layer's line back
// and the draft up again (the commit's undo restores the draft); Escape drops
// it. Edit > Transform > Flip Horizontal is one "Flip Horizontal" step that
// keeps the layer's line. `testCanvasSizeBorder` is step 6 on its own, so a
// red Canvas Size never hides the transform's truth: Image > Canvas Size…
// (PT-3) with Width -200 shows the crop note, Width and Height +400 about the
// centre drop it, OK gives a 1200 x 1000 image and Command-Z gives back
// 800 x 600. Every step shoots `transform-*`.
import CoreGraphics
import XCTest

final class PhotoTransformJourneyTests: XCTestCase {
    /// MJ-PT steps 1 to 5: Free Transform, scale, turn 15°, commit, undo, flip.
    @MainActor func testFreeTransformTurnFlip() throws {
        let photo = try openBeach()

        // 1. A pasted layer selected, Select, Edit > Free Transform: the box, its knob and the rows.
        photo.element("suite.tools").buttons["Marquee"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.4, dy: 0.4), to: CGVector(dx: 0.6, dy: 0.55))
        photo.press(character: "c", .command)
        photo.press(character: "v", .command)
        XCTAssert(photo.app.staticTexts["Pasted Layer"].waitForExistence(timeout: 5), "the paste made no Pasted Layer")
        photo.press(character: "d", .command)
        let line = layerLine(photo)
        XCTAssertFalse(line.isEmpty, "the inspector header has no Pasted Layer line (W × H px at X, Y)")
        photo.element("suite.tools").buttons["Select"].click()
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
        typeRotation("15", photo)
        let turned = NSPredicate(format: "value CONTAINS '15 degrees'")
        let knob = photo.element("suite.handles.turn")
        wait(for: [XCTNSPredicateExpectation(predicate: turned, object: knob)], timeout: 5)
        photo.shot("transform-3-turned")

        // 4. Return on the canvas: one Free Transform step, the box gone, the layer changed.
        photo.element("suite.canvas").click()
        photo.press(.return)
        XCTAssert(box.waitForNonExistence(timeout: 5), "Return left the transform box up")
        XCTAssert(photo.app.buttons["Undo Free Transform"].waitForExistence(timeout: 5), "Return made no Free Transform step")
        XCTAssert(text(line, photo).waitForNonExistence(timeout: 5), "the commit left the layer at \(line)")
        photo.shot("transform-4-committed")

        // 5. Command-Z: the layer is back where it was, the draft up again; Escape drops it.
        photo.press(character: "z", .command)
        XCTAssert(photo.app.buttons["Redo Free Transform"].waitForExistence(timeout: 5), "Command-Z didn't undo the transform")
        XCTAssert(text(line, photo).waitForExistence(timeout: 5), "Command-Z didn't put the layer back at \(line)")
        photo.shot("transform-5-undone")
        photo.element("suite.canvas").click()
        photo.press(.escape)
        XCTAssert(box.waitForNonExistence(timeout: 5), "Escape left the transform box up")

        // 6. Edit > Transform > Flip Horizontal: one Flip Horizontal step, the layer in place.
        choose(["Edit", "Transform", "Flip Horizontal"], photo)
        XCTAssert(photo.app.buttons["Undo Flip Horizontal"].waitForExistence(timeout: 5), "the flip made no step")
        XCTAssert(text(line, photo).waitForExistence(timeout: 5), "the flip moved the layer off \(line)")
        photo.shot("transform-6-flipped")
    }

    /// MJ-PT step 6: Image > Canvas Size…, the crop note, +400 about the centre, OK, Undo.
    @MainActor func testCanvasSizeBorder() throws {
        let photo = try openBeach()
        XCTAssert(text("800 × 600 px", photo).waitForExistence(timeout: 5), "beach.png isn't 800 × 600 px")

        // 1. Width -200: the sheet warns the canvas will be cropped.
        choose(["Image", "Canvas Size…"], photo)
        let ok = photo.element("photo.canvas-size.ok")
        XCTAssert(ok.waitForExistence(timeout: 5), "Canvas Size… opened no sheet (photo.canvas-size.ok)")
        XCTAssert(photo.element("photo.canvas-size.relative").exists, "the sheet has no Relative checkbox")
        typeSize("-200", into: "photo.canvas-size.width", photo)
        let note = photo.element("photo.canvas-size.crop-note")
        XCTAssert(note.waitForExistence(timeout: 5), "a smaller width showed no crop note")
        photo.shot("transform-canvas-crop-note")

        // 2. Width and Height +400: the note goes, the sheet reads the new size.
        typeSize("400", into: "photo.canvas-size.width", photo)
        typeSize("400", into: "photo.canvas-size.height", photo)
        XCTAssert(note.waitForNonExistence(timeout: 5), "the crop note stayed while the canvas only grows")
        XCTAssert(text("New size 1200 × 1000 px", photo).waitForExistence(timeout: 5), "the sheet doesn't read 1200 × 1000")
        XCTAssert(photo.element("photo.canvas-size.anchor.center").exists, "the sheet has no centre anchor")
        photo.shot("transform-canvas-sheet")

        // 3. OK: a 1200 x 1000 image, one Canvas Size step.
        ok.click()
        XCTAssert(ok.waitForNonExistence(timeout: 5), "OK left the Canvas Size sheet up")
        XCTAssert(photo.app.buttons["Undo Canvas Size"].waitForExistence(timeout: 5), "OK made no Canvas Size step")
        XCTAssert(text("1200 × 1000 px", photo).waitForExistence(timeout: 5), "the image isn't 1200 × 1000 px")
        photo.shot("transform-canvas-border")

        // 4. Command-Z: 800 x 600 again.
        photo.element("suite.canvas").click()
        photo.press(character: "z", .command)
        XCTAssert(text("800 × 600 px", photo).waitForExistence(timeout: 5), "Command-Z didn't give back 800 × 600 px")
        photo.shot("transform-canvas-undone")
    }

    // MARK: Steps

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

    /// The first element whose label or value holds `string`.
    @MainActor private func text(_ string: String, _ photo: Journey) -> XCUIElement {
        photo.app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", string, string)).firstMatch
    }

    /// The header's selected-layer line, "Pasted Layer W × H px at X, Y"; empty when none shows.
    @MainActor private func layerLine(_ photo: Journey) -> String {
        let header = text(" px at ", photo)
        guard header.waitForExistence(timeout: 5) else { return "" }
        let said = [header.label, header.value as? String ?? ""].joined(separator: "\n")
        let lines = said.split(whereSeparator: \.isNewline).map(String.init)
        return lines.first { $0.hasPrefix("Pasted Layer") && $0.contains(" px at ") } ?? ""
    }

    /// Clicks the Rotation bar to type, replaces its number with `degrees` and presses Return.
    @MainActor private func typeRotation(_ degrees: String, _ photo: Journey) {
        let rotation = photo.element("suite.transform.rotation")
        XCTAssert(rotation.waitForExistence(timeout: 5), "no Rotation row")
        rotation.click()
        let panel = photo.element("suite.inspector")
        let named = panel.textFields["Rotation"]
        let field = named.waitForExistence(timeout: 3) ? named : panel.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking Rotation opened no field to type in")
        field.typeKey("a", modifierFlags: .command)
        field.typeText(degrees)
        field.typeKey(.return, modifierFlags: [])
    }

    /// Replaces the sheet field `identifier`'s text with `value`, then Tab (Return would press OK).
    @MainActor private func typeSize(_ value: String, into identifier: String, _ photo: Journey) {
        let field = photo.element(identifier)
        XCTAssert(field.waitForExistence(timeout: 5), "the sheet has no \(identifier)")
        field.click()
        field.typeKey("a", modifierFlags: .command)
        field.typeText("\(value)\t")
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
