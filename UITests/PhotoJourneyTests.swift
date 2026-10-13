// PhotoJourneyTests.swift: Photo driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Journeys open
// a PNG the test writes (-PhotoOpenFile) and export to -PhotoExportTo, so no
// panel opens. Tier 1 (docs/priorities.md): testOpenImagePaintAndSave (Save,
// PNG and JPEG export, reopen), testTier1CropResize, testTier1Tone,
// testTier1UndoRedoZoomPan and testTier1Layers. Edits are checked by their
// undo names, sizes and layer counts by the panel header, values XCUITest
// can't read by the canvas pixels; tier-1 files are named tools.png, a name
// the audit knows. Another journey edits with every other tool,
// one straightens the image by 3 degrees from the Image menu, and the Curves
// journey drags the curve up and nudges it with an arrow key, each one
// "Undo Curves" step that changes the canvas. A section off its defaults shows
// Reset over its header (the audit's overlap check), so Curves, Levels and
// Hue/Saturation edits are undone before their shots. The Save As journey (to the
// folder given with -PhotoSaveTo, so no save panel) checks the window then
// holds the copy and Save writes it, and that Command-1 shows 100%. Run order
// is by name, so testTier1UndoRedoZoomPan runs last and attaches the audit
// counts.
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

        // No shot while Curves is off its defaults: its Reset icon sits over the
        // section header (the audit's overlap check), so Command-Z comes first.
        photo.drag(on: "photo.curves", from: CGVector(dx: 0.5, dy: 0.5), to: CGVector(dx: 0.5, dy: 0.25))
        XCTAssert(photo.app.buttons["Undo Curves"].waitForExistence(timeout: 5), "the curve drag made no Curves step")
        XCTAssert(Self.waitUntil { canvas.screenshot().pngRepresentation != before }, "the curve didn't change the canvas")

        // The drag left the curve focused on its new point: an arrow nudges it, as its own step.
        photo.app.typeKey(.upArrow, modifierFlags: [])
        photo.click("Undo Curves", in: .window)
        XCTAssert(photo.app.buttons["Redo Curves"].waitForExistence(timeout: 5), "the nudge made no Curves step")
        XCTAssert(photo.app.buttons["Undo Curves"].exists, "the nudge and the drag were one undo step")
        undoToDefaults("Curves", photo)
        photo.shot("curves-undone")
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

        typeValue("1.5", into: "Exposure", photo)
        expect("Undo Exposure", photo, "typing 1.5 into Exposure made no Exposure step")
        photo.shot("exposure")

        // Save (Command-S) writes over the opened file, in its own format.
        photo.app.typeKey("s", modifierFlags: .command)
        XCTAssert(Self.waitUntil { (try? Data(contentsOf: file)).map { $0 != original } ?? false }, "Save didn't rewrite journey.png")
        XCTAssertEqual(try Data(contentsOf: file).prefix(4), Data([0x89, 0x50, 0x4E, 0x47]), "the saved journey.png isn't a PNG")
        XCTAssert(photo.app.buttons["Undo Exposure"].exists, "Save changed the undo history")
        photo.shot("saved")

        photo.click("Export", in: .window, step: "export-sheet")
        photo.click("Export", in: .sheet)
        let exported = exports.appending(path: "journey.png")
        XCTAssert(Self.waitForFile(exported), "Export wrote no file")
        let header = try Data(contentsOf: exported).prefix(8)
        XCTAssertEqual(Array(header), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A], "the export isn't a PNG")
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
        XCTAssert(Self.waitForFile(jpg), "Return in the JPEG sheet wrote no journey.jpg")
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
        XCTAssert(Self.waitForFile(jpg), "the low-quality export wrote no journey.jpg")
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

    @MainActor func testSaveAsAndActualSize() throws {
        // tools.PNG becomes tools.png, a name the app audit already knows (the
        // document menu has no identifier), so the first shot comes after Save
        // As. The copy goes in its own folder: the disk may not tell the two apart.
        let folder = try Self.folder()
        let saves = folder.appending(path: "saves")
        try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
        let file = folder.appending(path: "tools.PNG")
        try Self.writeTestPhoto(to: file)
        let original = try Data(contentsOf: file)
        let photo = Journey("Photo", self, arguments: ["-PhotoOpenFile", file.path, "-PhotoSaveTo", saves.path])
        XCTAssert(photo.app.windows["tools.PNG"].waitForExistence(timeout: 30), "tools.PNG didn't open")

        // Shift-Command-S writes a PNG copy, and the window and panel header now name it.
        photo.app.typeKey("s", modifierFlags: [.command, .shift])
        let copy = saves.appending(path: "tools.png")
        XCTAssert(Self.waitForFile(copy), "Save As wrote no tools.png")
        XCTAssertEqual(try Data(contentsOf: copy).prefix(4), Data([0x89, 0x50, 0x4E, 0x47]), "the Save As copy isn't a PNG")
        XCTAssert(photo.app.windows["tools.png"].waitForExistence(timeout: 5), "the window isn't titled tools.png")
        expectHeader("tools.png, ", photo, "the panel header doesn't name tools.png")
        photo.shot("saved-as")

        // From now on Save writes the copy, never the opened file.
        let saved = try Data(contentsOf: copy)
        choose("Rotate 90° Clockwise", from: "Image", photo)
        expect("Undo Rotate", photo, "Rotate made no undo step")
        photo.app.typeKey("s", modifierFlags: .command)
        XCTAssert(Self.waitUntil { (try? Data(contentsOf: copy)).map { $0 != saved } ?? false }, "Save didn't rewrite the copy")
        XCTAssertEqual(try Data(contentsOf: file), original, "Save after Save As wrote over the opened tools.PNG")
        photo.shot("saved-copy")

        // suite.canvas is the scrollable area: the viewport, or the image plus a
        // 32 pt margin each side once that is larger. At 100% the 600 x 800 px
        // image makes it 864 pt tall, past the runner's viewport.
        let canvas = photo.element("suite.canvas")
        let fitted = canvasPixels(photo)
        photo.app.typeKey("-", modifierFlags: .command)
        XCTAssert(canvasChanged(from: fitted, photo), "Command-- didn't zoom out (the canvas looks the same)")
        photo.shot("zoomed-out")
        photo.app.typeKey("1", modifierFlags: .command)
        let actual = { abs(canvas.frame.height - 864) < 1 }
        XCTAssert(Self.waitUntil(actual), "Command-1 didn't show the image at 100% (\(canvas.frame.size); 100% is 864 pt tall)")
        photo.shot("actual-size")
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
        // Not Command-A: Select > All takes it from the field (#575).
        replaceText(in: angle, with: "3", photo)
        // XCUITest reads a SwiftUI Text's words as its value, not its label.
        let newSize = photo.app.sheets.staticTexts.matching(NSPredicate(format: "value BEGINSWITH 'New size '")).firstMatch
        XCTAssert(newSize.waitForExistence(timeout: 5), "the sheet doesn't say the new size")
        let size = String(((newSize.value as? String) ?? "").dropFirst("New size ".count))
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

        // Select Background by key (Select Layer Below): a row click focuses the list, whose highlight fails contrast.
        photo.app.typeKey("[", modifierFlags: [.command, .option])
        photo.shot("layer-selected")
        photo.click("Rename Layer…", in: .window)
        // In a window, not the alert's Touch Bar copy of the button.
        let rename = photo.app.windows.buttons["Rename"].firstMatch
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

        drag("Opacity", by: -0.25, photo)
        expect("Undo Layer Opacity", photo, "dragging Opacity made no Layer Opacity step")
        photo.shot("layer-opacity")
        typeValue("25", into: "Opacity", photo)
        XCTAssert(photo.app.staticTexts["Normal 25%"].waitForExistence(timeout: 5), "typing 25 didn't set Sky's opacity to 25%")
        photo.shot("layer-opacity-typed")

        // Bring Forward (Command-]) moves Sky, the bottom layer, above Layer 1.
        photo.app.typeKey("]", modifierFlags: .command)
        expect("Undo Reorder Layers", photo, "Command-] made no Reorder Layers step")
        let sky = photo.app.staticTexts["Sky"], layer1 = photo.app.staticTexts["Layer 1"]
        XCTAssert(Self.waitUntil { sky.frame.minY < layer1.frame.minY }, "Sky isn't above Layer 1 after Bring Forward")
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

        // A section off its defaults shows Reset over its header (audit overlap), so Levels and Hue/Saturation undo before their shots.
        var before = canvasPixels(photo)
        drag("Black", by: 0.25, photo)
        expect("Undo Levels", photo, "dragging Black made no Levels step")
        XCTAssert(canvasChanged(from: before, photo), "dragging Black didn't change the picture")
        undoToDefaults("Levels", photo)
        photo.shot("tone-levels-undone")

        // Curves sits between Levels and Hue/Saturation; folding it brings Hue/Saturation into view.
        photo.click("Curves", in: .window)
        XCTAssert(photo.element("photo.curves").waitForNonExistence(timeout: 5), "the Curves header didn't fold Curves")
        photo.shot("tone-curves-folded")

        drag("Hue", by: 0.25, photo)
        expect("Undo Hue/Saturation", photo, "dragging Hue made no Hue/Saturation step")
        before = canvasPixels(photo)
        typeValue("-80", into: "Saturation", photo)
        XCTAssert(canvasChanged(from: before, photo), "typing -80 into Saturation didn't change the picture")
        undoToDefaults("Hue/Saturation", photo)
        photo.shot("tone-hue-saturation-undone")
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

        // Zoom in by key and by button until the image overflows, pan, zoom out,
        // fit. suite.canvas is the scrollable area: the viewport, or the image
        // plus a 32 pt margin once that is larger. Every zoom step changes the
        // picture, and past the viewport the area grows.
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        let fit = canvas.frame.size
        zoom({ photo.app.typeKey("=", modifierFlags: .command) }, photo, "Command-= didn't zoom in")
        photo.shot("zoom-in-key")
        for _ in 0..<2 { zoom({ photo.click("Zoom In", in: .window) }, photo, "the top bar's Zoom In didn't zoom in") }
        XCTAssert(canvas.frame.height > fit.height + 100, "zooming in didn't outgrow the viewport (\(canvas.frame.size), fit \(fit))")
        photo.shot("zoom-in")

        // Scrolling over the image pans it; which way a wheel delta goes is the
        // runner's setting, so if one way is already at the edge, try the other.
        let start = canvas.frame
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).scroll(byDeltaX: -200, deltaY: -200)
        if !Self.waitUntil({ canvas.frame != start }) {
            canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.05)).scroll(byDeltaX: 200, deltaY: 200)
        }
        XCTAssert(Self.waitUntil { canvas.frame != start }, "scrolling over the zoomed image didn't pan it")
        XCTAssert(photo.app.buttons["Undo New Layer"].exists, "panning changed the undo history")
        photo.shot("panned")

        let zoomedIn = canvas.frame.height
        zoom({ photo.click("Zoom Out", in: .window) }, photo, "the top bar's Zoom Out didn't zoom out")
        XCTAssert(Self.waitUntil { canvas.frame.height < zoomedIn - 1 }, "Zoom Out didn't make the image smaller")
        photo.shot("zoom-out")
        photo.app.typeKey("0", modifierFlags: .command)
        let fitted = { abs(canvas.frame.width - fit.width) <= 1 && abs(canvas.frame.height - fit.height) <= 1 }
        XCTAssert(Self.waitUntil(fitted), "Command-0 didn't fit the image again (\(canvas.frame.size), fit was \(fit))")
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

    /// Waits for a label holding `text`, as the header's "tools.png, 400 × 300 px, sRGB · 1 layer".
    @MainActor private func expectHeader(_ text: String, _ photo: Journey, _ message: String) {
        if labelled(text, photo).waitForExistence(timeout: 5) { return }
        let header = labelled(" px, sRGB", photo)
        XCTFail("\(message) (no label holds \(text); the header reads \(header.exists ? header.label : "nothing"))")
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

    /// Drags the panel slider labelled `label` from its middle by `fraction` of
    /// its width, as a person does; a bar slider scrubs from where it is, so
    /// the journeys check the undo step and the picture, not a value.
    @MainActor private func drag(_ label: String, by fraction: CGFloat, _ photo: Journey) {
        let slider = photo.app.sliders[label]
        XCTAssert(slider.waitForExistence(timeout: 5), "no \(label) slider")
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.5 + fraction, dy: 0.5)))
    }

    /// Types `value` into the panel number labelled `label` (the last element so
    /// labelled, after the section header and slider): click it, type, Return.
    @MainActor private func typeValue(_ value: String, into label: String, _ photo: Journey) {
        let matches = photo.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
        XCTAssert(matches.firstMatch.waitForExistence(timeout: 5), "no \(label) in the panel")
        matches.element(boundBy: matches.count - 1).click()
        // The open number's field carries the label (the brush's hex field may sit above it);
        // click it, as it may open without the keyboard.
        let panel = photo.element("suite.inspector"), named = panel.textFields[label]
        let field = named.waitForExistence(timeout: 3) ? named : panel.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(label)'s number opened no field to type in")
        replaceText(in: field, with: value, photo)
        photo.app.typeKey(.return, modifierFlags: [])
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
        Self.waitUntil { canvasPixels(photo) != before }
    }

    /// Does `action` and waits for the canvas picture to change, as every zoom step does.
    @MainActor private func zoom(_ action: () -> Void, _ photo: Journey, _ message: String) {
        let before = canvasPixels(photo)
        action()
        XCTAssert(canvasChanged(from: before, photo), "\(message) (the canvas looks the same)")
    }

    /// Presses Command-Z until section `title` is back at its defaults (its Reset icon goes), at most three times.
    @MainActor private func undoToDefaults(_ title: String, _ photo: Journey) {
        let reset = photo.app.buttons["Reset \(title)"]
        XCTAssert(reset.waitForExistence(timeout: 5), "the \(title) section shows no Reset after an edit")
        for _ in 0..<3 where reset.exists {
            photo.app.typeKey("z", modifierFlags: .command)
            _ = reset.waitForNonExistence(timeout: 2)
        }
        XCTAssertFalse(reset.exists, "Command-Z didn't take \(title) back to its defaults")
        expect("Redo \(title)", photo, "Command-Z didn't undo \(title)")
    }

    // MARK: Files

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

    /// Waits up to 5 seconds for `condition` to hold.
    private static func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<10 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }

    /// Waits up to 15 seconds for `url` to exist.
    private static func waitForFile(_ url: URL) -> Bool {
        for _ in 0..<30 {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }
}
