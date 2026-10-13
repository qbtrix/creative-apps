// PhotoJourneyTests.swift: Photo driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). A file
// journey opens a real PNG the test writes (-PhotoOpenFile, so no open
// panel); Export writes to the folder given with -PhotoExportTo (no save
// panel) and Save writes over the opened file. The tier-1 journeys
// (docs/priorities.md):
//   open, save, export    testOpenImagePaintAndSave: paint, undo, exposure,
//                         Save (the file changes, then reopens), a PNG, a JPEG
//                         at 90% and a smaller one at the lowest quality.
//   crop and resize       testTier1CropResize: Image Size by typing a width
//                         (the height follows), the crop tool by its C key, a
//                         drag and Return.
//   tone                  testTier1Tone: Exposure typed, Levels Black and Hue
//                         dragged, Saturation typed, one Undo for Hue/Saturation.
//   undo, redo, zoom, pan testTier1UndoRedoZoomPan: Edit > Undo, Command-Z,
//                         Shift-Command-Z and the top bar's Redo; zoom by key
//                         and button, a scroll pans, Command-0 fits.
//   layers                testTier1Layers: add, select (by key), rename, hide and
//                         show, opacity dragged and typed, Bring Forward, delete.
// Each edit is checked by the Undo button's name ("Undo Crop"), sizes and
// layer counts by the panel header's label, and a value XCUITest can't read
// (a slider's number) by the canvas pixels changing. Tier-1 journeys open a
// file named tools.png, a name the audit already knows (the document menu
// has no identifier). Another journey edits with every other tool, one
// straightens the image by 3 degrees from the Image menu, and the Curves
// journey drags the curve up and nudges it with an arrow key, each one
// "Undo Curves" step that changes the canvas. Run order is by name, so
// testTier1UndoRedoZoomPan runs last and attaches the counts.
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest

final class PhotoJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Photo", self).expectEditorShell()
    }

    @MainActor func testNewImageAndEveryTool() {
        let photo = Journey("Photo", self)
        photo.app.typeKey("n", modifierFlags: .command)
        photo.shot("new-image")
        photo.clickEachTool()
    }

    @MainActor func testCurvesDragAndNudge() throws {
        let file = try Self.folder().appending(path: "curves.png")
        try Self.writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: ["-PhotoOpenFile", file.path])
        XCTAssert(photo.app.windows["curves.png"].waitForExistence(timeout: 30), "curves.png didn't open")
        photo.shot("curves-opened")
        let canvas = photo.element("suite.canvas")
        let before = canvas.screenshot().pngRepresentation

        photo.drag(on: "photo.curves", from: CGVector(dx: 0.5, dy: 0.5), to: CGVector(dx: 0.5, dy: 0.25), step: "curves-dragged")
        XCTAssert(photo.app.buttons["Undo Curves"].waitForExistence(timeout: 5), "the curve drag made no Curves step")
        XCTAssert(Self.eventually(seconds: 5) { canvas.screenshot().pngRepresentation != before }, "the curve didn't change the canvas")

        // The drag left the curve focused on its new point: an arrow nudges it, as its own step.
        photo.app.typeKey(.upArrow, modifierFlags: [])
        photo.shot("curves-nudged")
        photo.click("Undo Curves", in: .window, step: "curves-nudge-undone")
        XCTAssert(photo.app.buttons["Redo Curves"].waitForExistence(timeout: 5), "the nudge made no Curves step")
        XCTAssert(photo.app.buttons["Undo Curves"].exists, "the nudge and the drag were one undo step")
    }

    @MainActor func testEveryMenuOpens() {
        let photo = Journey("Photo", self)
        photo.app.typeKey("n", modifierFlags: .command)
        photo.openEachMenu()
    }

    @MainActor func testOpenImagePaintAndSave() throws {
        let folder = try Self.folder()
        let exports = folder.appending(path: "exports")
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        let file = folder.appending(path: "journey.png")
        try Self.writeTestPhoto(to: file)
        let original = try Data(contentsOf: file)
        let arguments = ["-PhotoOpenFile", file.path, "-PhotoExportTo", exports.path]
        let photo = Journey("Photo", self, arguments: arguments)
        XCTAssert(photo.app.windows["journey.png"].waitForExistence(timeout: 30), "journey.png didn't open")
        photo.shot("opened")

        photo.element("suite.tools").buttons["Brush"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.3), to: CGVector(dx: 0.8, dy: 0.7), step: "painted")
        photo.click("Undo Paint", in: .window, step: "undone")
        XCTAssert(photo.app.buttons["Redo Paint"].waitForExistence(timeout: 5), "Undo didn't undo the stroke")

        let exposure = photo.app.sliders["Exposure"]
        XCTAssert(exposure.waitForExistence(timeout: 5), "no Exposure slider")
        exposure.adjust(toNormalizedSliderPosition: 0.65)
        expect("Undo Exposure", photo, "dragging Exposure made no Exposure step")
        photo.shot("exposure")

        // Save (Command-S) writes over the opened file, in its own format.
        photo.app.typeKey("s", modifierFlags: .command)
        XCTAssert(Self.eventually { (try? Data(contentsOf: file)).map { $0 != original } ?? false }, "Save didn't rewrite journey.png")
        XCTAssertEqual(Array(try Data(contentsOf: file).prefix(8)), Self.pngHeader, "the saved journey.png isn't a PNG")
        XCTAssert(photo.app.buttons["Undo Exposure"].exists, "Save changed the undo history")
        photo.shot("saved")

        photo.click("Export", in: .window, step: "export-sheet")
        photo.click("Export", in: .sheet)
        let exported = exports.appending(path: "journey.png")
        XCTAssert(Self.eventually { FileManager.default.fileExists(atPath: exported.path) }, "Export wrote no file")
        let header = try Data(contentsOf: exported).prefix(8)
        XCTAssertEqual(Array(header), Self.pngHeader, "the export isn't a PNG")
        photo.shot("exported")

        // JPEG from the keyboard: Shift-Command-E opens Export, Return exports at 90%.
        photo.app.typeKey("e", modifierFlags: [.command, .shift])
        let jpeg = photo.app.sheets.radioButtons["JPEG"]
        XCTAssert(jpeg.waitForExistence(timeout: 5), "Shift-Command-E showed no Export sheet with a JPEG choice")
        jpeg.click()
        let quality = photo.app.sheets.sliders["photo.export.quality"]
        XCTAssert(quality.waitForExistence(timeout: 5), "choosing JPEG showed no Quality slider")
        photo.shot("export-jpeg")
        photo.app.typeKey(.return, modifierFlags: [])
        let jpg = exports.appending(path: "journey.jpg")
        XCTAssert(Self.eventually { FileManager.default.fileExists(atPath: jpg.path) }, "Return in the JPEG sheet wrote no journey.jpg")
        let best = try Data(contentsOf: jpg)
        XCTAssertEqual(Array(best.prefix(3)), [0xFF, 0xD8, 0xFF], "journey.jpg isn't a JPEG")
        photo.shot("exported-jpeg")
        try FileManager.default.removeItem(at: jpg)

        // The sheet keeps JPEG; the lowest quality writes a smaller file.
        photo.click("Export", in: .window)
        XCTAssert(quality.waitForExistence(timeout: 5), "the Export sheet forgot JPEG")
        quality.adjust(toNormalizedSliderPosition: 0)
        photo.shot("export-quality")
        photo.click("Export", in: .sheet)
        XCTAssert(Self.eventually { FileManager.default.fileExists(atPath: jpg.path) }, "the low-quality export wrote no journey.jpg")
        let small = try Data(contentsOf: jpg)
        XCTAssertLessThan(small.count, best.count, "the lowest JPEG quality didn't write a smaller file")
        photo.shot("exported-small")

        // The saved file reopens, with no history.
        photo.app.terminate()
        let reopened = Journey("Photo", self, arguments: arguments)
        XCTAssert(reopened.app.windows["journey.png"].waitForExistence(timeout: 30), "the saved journey.png didn't reopen")
        expectHeader("800 × 600 px", reopened, "the reopened journey.png isn't 800 × 600 px")
        expect("photo.bar.undo", reopened, "the reopened window has no Undo button")
        XCTAssertFalse(reopened.app.buttons["photo.bar.undo"].isEnabled, "the reopened file came with undo history")
        reopened.shot("reopened")
    }

    @MainActor func testEveryToolEditsTheImage() throws {
        let file = try Self.folder().appending(path: "tools.png")
        try Self.writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: ["-PhotoOpenFile", file.path])
        XCTAssert(photo.app.windows["tools.png"].waitForExistence(timeout: 30), "tools.png didn't open")
        let tools = photo.element("suite.tools").buttons

        tools["Eraser"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.1, dy: 0.8), to: CGVector(dx: 0.5, dy: 0.5), step: "erased")

        tools["Marquee"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.55, dy: 0.15), to: CGVector(dx: 0.85, dy: 0.45), step: "selected")
        photo.click("Fill", in: .window, step: "filled")

        tools["Move"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.5, dy: 0.5), to: CGVector(dx: 0.6, dy: 0.55), step: "moved")

        tools["Crop"].click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.1, dy: 0.1), to: CGVector(dx: 0.9, dy: 0.9), step: "crop-pending")
        photo.click("Apply Crop", in: .window, step: "cropped")
        XCTAssert(photo.app.buttons["Undo Crop"].waitForExistence(timeout: 5), "the crop wasn't applied")
    }

    @MainActor func testStraighten() throws {
        let file = try Self.folder().appending(path: "straighten.png")
        try Self.writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: ["-PhotoOpenFile", file.path])
        XCTAssert(photo.app.windows["straighten.png"].waitForExistence(timeout: 30), "straighten.png didn't open")
        XCTAssert(photo.app.staticTexts["800 × 600 px"].waitForExistence(timeout: 5), "the status bar shows no image size")

        photo.app.menuBars.menuBarItems["Image"].click()
        photo.app.menuBars.menuItems["Straighten…"].click()
        let angle = photo.element("photo.straighten.angle")
        XCTAssert(angle.waitForExistence(timeout: 5), "no Angle field in the Straighten sheet")
        photo.shot("straighten-sheet")
        angle.click()
        angle.typeKey("a", modifierFlags: .command)
        angle.typeText("3")
        let newSize = photo.app.sheets.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'New size '")).firstMatch
        XCTAssert(newSize.waitForExistence(timeout: 5), "the sheet doesn't say the new size")
        let size = String(newSize.label.dropFirst("New size ".count))
        XCTAssertNotEqual(size, "800 × 600 px", "3 degrees didn't change the new size")
        photo.shot("straighten-preview")

        // Return is Apply, and it must turn by the 3 just typed.
        angle.typeKey(.return, modifierFlags: [])
        XCTAssert(photo.app.buttons["Undo Straighten"].waitForExistence(timeout: 15), "Straighten made no undo step")
        XCTAssert(photo.app.staticTexts[size].waitForExistence(timeout: 5), "the canvas isn't \(size) after Straighten")
        XCTAssertFalse(photo.app.staticTexts["800 × 600 px"].exists, "the canvas size didn't change")
        photo.shot("straightened")
    }

    @MainActor func testTier1CropResize() throws {
        let photo = try openTestPhoto(step: "resize-opened")

        choose("Image Size…", from: "Image", photo)
        let width = photo.app.sheets.textFields["photo.size.width"]
        XCTAssert(width.waitForExistence(timeout: 5), "Image > Image Size… showed no Width field (photo.size.width)")
        photo.shot("resize-sheet")
        // Type a width and press Return: the height keeps the proportions.
        replaceText(in: width, with: "400", photo)
        photo.app.typeKey(.return, modifierFlags: [])
        XCTAssert(width.waitForNonExistence(timeout: 5), "Return didn't close the Image Size sheet")
        expect("Undo Image Size", photo, "Image Size made no undo step")
        expectHeader("400 × 300 px", photo, "typing a width of 400 didn't make the image 400 × 300 px")
        photo.shot("resized")

        // A click focuses the canvas (a Move click moves nothing), then C picks Crop.
        photo.element("suite.canvas").click()
        photo.app.typeKey("c", modifierFlags: [])
        let apply = photo.app.buttons["photo.tool.apply-crop"]
        XCTAssert(apply.waitForExistence(timeout: 5), "the C key didn't pick the crop tool (no Apply Crop)")
        XCTAssert(photo.element("suite.tools").buttons["Crop"].isSelected, "the rail doesn't show Crop picked after C")
        photo.shot("crop-tool-key")
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.25, dy: 0.25), to: CGVector(dx: 0.75, dy: 0.75), step: "crop-chosen")
        XCTAssert(apply.isEnabled, "Apply Crop is still disabled after dragging a crop")
        photo.app.typeKey(.return, modifierFlags: [])
        expect("Undo Crop", photo, "Return didn't apply the crop")
        XCTAssert(labelled("400 × 300 px", photo).waitForNonExistence(timeout: 5), "the crop didn't change the image size")
        photo.shot("cropped-by-key")
    }

    @MainActor func testTier1Layers() throws {
        let photo = try openTestPhoto(step: "layers-opened")
        let tab = photo.app.radioButtons["Layers"]
        XCTAssert(tab.waitForExistence(timeout: 5), "no Layers tab")
        tab.click()
        XCTAssert(photo.app.staticTexts["Background"].waitForExistence(timeout: 5), "the Layers tab doesn't list Background")
        photo.shot("layers-tab")

        photo.click("New Layer", in: .window)
        expect("Undo New Layer", photo, "New Layer made no undo step")
        XCTAssert(photo.app.staticTexts["Layer 1"].waitForExistence(timeout: 5), "New Layer listed no Layer 1")
        expectHeader("2 layers", photo, "the header doesn't count two layers after New Layer")
        photo.shot("layer-added")

        // Select Background by key (Option-Command-[ is Select Layer Below), then
        // rename it from the panel. A click on a row would focus the list, whose
        // highlight (white on the accent, about 3.6:1) the contrast audit fails.
        photo.app.typeKey("[", modifierFlags: [.command, .option])
        photo.shot("layer-selected")
        photo.click("Rename Layer…", in: .window)
        let rename = photo.app.buttons["Rename"]
        XCTAssert(rename.waitForExistence(timeout: 5), "Rename Layer… showed no Rename button")
        let name = photo.app.textFields
            .matching(NSPredicate(format: "identifier == %@ OR placeholderValue == %@", "photo.layer.name", "Name")).firstMatch
        XCTAssert(name.waitForExistence(timeout: 5), "the Rename Layer alert has no Name field")
        replaceText(in: name, with: "Sky", photo)
        rename.click()
        expect("Undo Rename Layer", photo, "Rename made no undo step")
        XCTAssert(photo.app.staticTexts["Sky"].waitForExistence(timeout: 5), "the layer isn't named Sky")
        XCTAssertFalse(photo.app.staticTexts["Background"].exists, "Rename renamed the wrong layer (Background is still listed)")
        photo.shot("layer-renamed")

        // Hide by the row's eye, show again from the Layer menu.
        photo.click("Hide Sky", in: .window)
        expect("Undo Hide Layer", photo, "Sky's eye didn't hide it")
        XCTAssert(photo.app.buttons["Show Sky"].waitForExistence(timeout: 5), "Sky's eye doesn't offer Show after hiding")
        photo.shot("layer-hidden")
        choose("Show Layer", from: "Layer", photo)
        expect("Undo Show Layer", photo, "Layer > Show Layer didn't show Sky")
        photo.shot("layer-shown")

        let opacity = photo.app.sliders["Opacity"]
        XCTAssert(opacity.waitForExistence(timeout: 5), "no layer Opacity slider")
        opacity.adjust(toNormalizedSliderPosition: 0.5)
        expect("Undo Layer Opacity", photo, "dragging Opacity made no Layer Opacity step")
        photo.shot("layer-opacity")
        typeValue("25", into: "Opacity", photo)
        XCTAssert(photo.app.staticTexts["Normal 25%"].waitForExistence(timeout: 5), "typing 25 didn't set Sky's opacity to 25%")
        photo.shot("layer-opacity-typed")

        // Bring Forward (Command-]) moves Sky, the bottom layer, above Layer 1.
        photo.app.typeKey("]", modifierFlags: .command)
        expect("Undo Reorder Layers", photo, "Command-] made no Reorder Layers step")
        let sky = photo.app.staticTexts["Sky"], layer1 = photo.app.staticTexts["Layer 1"]
        XCTAssert(Self.eventually(seconds: 3) { sky.frame.minY < layer1.frame.minY }, "Sky isn't above Layer 1 after Bring Forward")
        photo.shot("layer-reordered")

        photo.app.typeKey("[", modifierFlags: [.command, .option])
        photo.shot("layer-picked")
        photo.click("Delete Layer", in: .window)
        expect("Undo Delete Layer", photo, "Delete Layer made no undo step")
        XCTAssert(layer1.waitForNonExistence(timeout: 5), "Delete Layer didn't remove Layer 1")
        XCTAssert(sky.exists, "Delete Layer removed Sky, not Layer 1 below it")
        expectHeader("1 layer", photo, "the header doesn't count one layer after Delete Layer")
        photo.shot("layer-deleted")
    }

    @MainActor func testTier1Tone() throws {
        let photo = try openTestPhoto(step: "tone-opened")

        typeValue("1", into: "Exposure", photo)
        expect("Undo Exposure", photo, "typing 1 into Exposure made no Exposure step")
        photo.shot("tone-exposure-typed")

        let black = photo.app.sliders["Black"]
        XCTAssert(black.waitForExistence(timeout: 5), "no Levels Black slider")
        black.adjust(toNormalizedSliderPosition: 0.25)
        expect("Undo Levels", photo, "dragging Black made no Levels step")
        photo.shot("tone-levels")

        let hue = photo.app.sliders["Hue"]
        XCTAssert(hue.waitForExistence(timeout: 5), "no Hue slider")
        hue.adjust(toNormalizedSliderPosition: 0.75)
        expect("Undo Hue/Saturation", photo, "dragging Hue made no Hue/Saturation step")
        photo.shot("tone-hue")

        // Saturation joins the Hue step (one section, one step), so the picture proves it.
        let before = canvasPixels(photo)
        typeValue("-80", into: "Saturation", photo)
        XCTAssert(canvasChanged(from: before, photo), "typing -80 into Saturation didn't change the picture")
        photo.shot("tone-saturation-typed")

        photo.app.typeKey("z", modifierFlags: .command)
        expect("Redo Hue/Saturation", photo, "Command-Z didn't take back Hue and Saturation as one step")
        expect("Undo Levels", photo, "after undoing Hue/Saturation the next undo isn't Levels")
        photo.shot("tone-undone")
    }

    @MainActor func testTier1UndoRedoZoomPan() throws {
        let photo = try openTestPhoto(step: "history-opened")

        choose("Rotate 90° Clockwise", from: "Image", photo)
        expect("Undo Rotate", photo, "Image > Rotate 90° Clockwise made no Rotate step")
        expectHeader("600 × 800 px", photo, "the turned image isn't 600 × 800 px")
        photo.shot("history-rotated")
        photo.app.typeKey("n", modifierFlags: [.command, .shift])
        expect("Undo New Layer", photo, "Shift-Command-N made no New Layer step")
        expectHeader("2 layers", photo, "Shift-Command-N didn't add a layer")
        photo.shot("history-new-layer")

        // The Edit menu names the edit it will undo.
        photo.app.menuBars.menuBarItems["Edit"].click()
        let undoItem = photo.app.menuBars.menuItems["Undo New Layer"]
        XCTAssert(undoItem.waitForExistence(timeout: 5), "Edit > Undo isn't named Undo New Layer")
        photo.shot("history-edit-menu", screen: true)
        undoItem.click()
        expect("Redo New Layer", photo, "Edit > Undo New Layer didn't undo it")
        expectHeader("1 layer", photo, "undoing New Layer left two layers")
        photo.shot("history-undo-menu")

        photo.app.typeKey("z", modifierFlags: .command)
        expect("Redo Rotate", photo, "Command-Z didn't undo the turn")
        expectHeader("800 × 600 px", photo, "undoing Rotate didn't turn the image back")
        XCTAssertFalse(photo.app.buttons["photo.bar.undo"].isEnabled, "Undo is enabled with nothing left to undo")
        photo.shot("history-undo-key")

        photo.app.typeKey("z", modifierFlags: [.command, .shift])
        expect("Undo Rotate", photo, "Shift-Command-Z didn't redo the turn")
        expectHeader("600 × 800 px", photo, "redoing Rotate didn't turn the image again")
        photo.shot("history-redo-key")

        photo.click("Redo New Layer", in: .window)
        expect("Undo New Layer", photo, "the top bar's Redo didn't redo New Layer")
        expectHeader("2 layers", photo, "redoing New Layer didn't bring the layer back")
        photo.shot("history-redo-button")

        // Zoom in by key and by button until the image overflows, pan, zoom out, fit.
        let fit = zoom(photo)
        photo.app.typeKey("=", modifierFlags: .command)
        var level = zoom(changedFrom: fit, photo, "Command-= didn't zoom in")
        photo.shot("zoom-in-key")
        for _ in 0..<2 {
            photo.click("Zoom In", in: .window)
            level = zoom(changedFrom: level, photo, "the top bar's Zoom In didn't zoom in")
        }
        photo.shot("zoom-in")

        // Scrolling over the image pans it; which way a wheel delta goes is the
        // runner's setting, so if one way is already at the edge, try the other.
        let canvas = photo.element("suite.canvas")
        let start = canvas.frame
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).scroll(byDeltaX: -200, deltaY: -200)
        if !Self.eventually(seconds: 3, { canvas.frame != start }) {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).scroll(byDeltaX: 200, deltaY: 200)
        }
        XCTAssert(Self.eventually(seconds: 3) { canvas.frame != start }, "scrolling over the zoomed image didn't pan it")
        XCTAssert(photo.app.buttons["Undo New Layer"].exists, "panning changed the undo history")
        photo.shot("panned")

        photo.click("Zoom Out", in: .window)
        level = zoom(changedFrom: level, photo, "the top bar's Zoom Out didn't zoom out")
        photo.shot("zoom-out")
        photo.app.typeKey("0", modifierFlags: .command)
        XCTAssert(Self.eventually(seconds: 5) { zoom(photo) == fit }, "Command-0 didn't fit the image again (\(zoom(photo)), fit was \(fit))")
        photo.shot("zoom-fit")
    }

    // MARK: Steps

    /// Launches Photo on a fresh test photo named tools.png and shoots `step`.
    @MainActor private func openTestPhoto(step: String) throws -> Journey {
        let file = try Self.folder().appending(path: "tools.png")
        try Self.writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: ["-PhotoOpenFile", file.path])
        XCTAssert(photo.app.windows["tools.png"].waitForExistence(timeout: 30), "tools.png didn't open")
        photo.shot(step)
        return photo
    }

    /// Waits for the button titled `title`, such as the top bar's "Undo Crop".
    @MainActor private func expect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
    }

    /// Waits for an element whose label holds `text`, such as the panel
    /// header's "tools.png, 400 × 300 px, sRGB · 1 layer".
    @MainActor private func expectHeader(_ text: String, _ photo: Journey, _ message: String) {
        XCTAssert(labelled(text, photo).waitForExistence(timeout: 5), "\(message) (no label holds \(text))")
    }

    @MainActor private func labelled(_ text: String, _ photo: Journey) -> XCUIElement {
        photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Picks `item` from the menu bar's `menu`.
    @MainActor private func choose(_ item: String, from menu: String, _ photo: Journey) {
        photo.app.menuBars.menuBarItems[menu].click()
        let entry = photo.app.menuBars.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 5), "the \(menu) menu has no \(item)")
        entry.click()
    }

    /// Types `value` into the panel's number labelled `label` as a person
    /// does: a click on the number opens it for typing, Return commits. The
    /// number is the last element with that label (the section header and the
    /// slider come before it).
    @MainActor private func typeValue(_ value: String, into label: String, _ photo: Journey) {
        let matches = photo.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
        XCTAssert(matches.firstMatch.waitForExistence(timeout: 5), "no \(label) in the panel")
        matches.element(boundBy: matches.count - 1).click()
        photo.app.typeText(value + "\r")
    }

    /// Clears `field` and types `text`, without Command-A (Photo's Select > All has it).
    @MainActor private func replaceText(in field: XCUIElement, with text: String, _ photo: Journey) {
        field.click()
        photo.app.typeKey(.rightArrow, modifierFlags: .command)
        for _ in 0..<16 { photo.app.typeKey(.delete, modifierFlags: []) }
        photo.app.typeText(text)
    }

    @MainActor private func canvasPixels(_ photo: Journey) -> Data {
        photo.element("suite.canvas").screenshot().pngRepresentation
    }

    /// Whether the canvas stops matching `before` within five seconds (it renders off the main actor).
    @MainActor private func canvasChanged(from before: Data, _ photo: Journey) -> Bool {
        Self.eventually(seconds: 5) { canvasPixels(photo) != before }
    }

    /// The status line's zoom, such as "Zoom 67%".
    @MainActor private func zoom(_ photo: Journey) -> String {
        let status = photo.app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Zoom ")).firstMatch
        XCTAssert(status.waitForExistence(timeout: 5), "the status line shows no zoom (Zoom N%)")
        return status.label
    }

    /// Waits up to five seconds for the zoom to read other than `old`, and returns it.
    @MainActor private func zoom(changedFrom old: String, _ photo: Journey, _ message: String) -> String {
        XCTAssert(Self.eventually(seconds: 5) { zoom(photo) != old }, "\(message) (still \(old))")
        return zoom(photo)
    }

    // MARK: Files

    private static let pngHeader: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    /// A fresh folder for one journey's files.
    private static func folder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-journey-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    /// An 800 x 600 PNG that reads like a photo: a sky gradient and a sun.
    private static func writeTestPhoto(to url: URL) throws {
        let (width, height) = (800, 600)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let gradient = CGGradient(
                colorsSpace: space,
                colors: [CGColor(srgbRed: 0.16, green: 0.42, blue: 0.86, alpha: 1),
                         CGColor(srgbRed: 0.98, green: 0.62, blue: 0.42, alpha: 1)] as CFArray,
                locations: [0, 1])
        else { throw CocoaError(.fileWriteUnknown) }
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: 0, y: 0), options: [])
        context.setFillColor(CGColor(srgbRed: 1, green: 0.86, blue: 0.3, alpha: 1))
        context.fillEllipse(in: CGRect(x: 470, y: 290, width: 180, height: 180))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { throw CocoaError(.fileWriteUnknown) }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }

    /// Whether `condition` holds within `seconds`, checked every half second.
    @MainActor private static func eventually(seconds: Double = 15, _ condition: () -> Bool) -> Bool {
        for _ in 0..<max(Int(seconds * 2), 1) {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return condition()
    }
}
