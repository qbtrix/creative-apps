// FlareJourneyTests+Loop.swift: J26, step 8 of draw-key-save (DK-15;
// docs/blueprints/flare/features/draw-key-save.md), the whole loop on live
// services: no `-FlareFixture`, so the window runs on `FlareServices.built`,
// with `-FlareSaveTo <tmp>` so Save writes without a panel. New from the
// toolbar, then the New Animation sheet's Web 550 × 400 and Create; the palette's Rectangle and drag a rectangle (Rectangle 1, its one
// key at 0); Auto-key on (the recording ring, `flare.recording`: SuiteWindow
// drops Auto-key's selected state, #1621); the palette's Select; drag the
// playhead to 24 on the Frame Ruler and drag the rectangle 200 scene points
// right: its lane keys 24 and keeps 0. The transport's Play/Pause, wait,
// Play/Pause plays and pauses; the toolbar's Undo takes the key at 24 away and
// its Redo brings it back; its Save writes <tmp>/Untitled.flare and the title
// reads "Untitled", not edited (`flare.file` reads "Saved"). Every step up to
// here is a click (#1863); the keys are FlareJourneyTests' `testKeys`.
// End moves the playhead off 0, then File > Open Recent lists Untitled.flare
// and opening it lands at frame 0 with keys at 0 and 24 on the lane and the
// title "Untitled", not edited. Lanes, scene points and the ruler are read as
// FlareAnimateJourneys reads them. Then (LF-6) ⌘N, the sheet's Square and
// Create make an empty 1080 × 1080 document, and Open Recent brings the saved
// file back with its keys. One shot per step, `flare-loop-<step>`.
import XCTest

final class FlareLoopJourneys: XCTestCase {
    private static let lastFrame = 47.0, sceneWidth = 550.0
    private static let lane = "Rectangle 1"

    /// New; draw; key 24 by drag with Auto-key on; play; undo and redo; save; reopen from Open Recent.
    @MainActor func testDrawKeyAndSave() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-loop-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "Untitled.flare")
        let flare = Journey("Flare", self, arguments: ["-FlareSaveTo", folder.path])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let toolbar = flare.app.toolbars.firstMatch

        // 1. New from the toolbar, the sheet's Web 550 × 400 preset and Create: an empty 550 × 400 stage.
        let new = toolbar.buttons["flare.file.new"]
        XCTAssert(new.waitForExistence(timeout: 10), "no New in the toolbar (flare.file.new)")
        new.click()
        flare.click("Web 550 × 400", in: .sheet)
        flare.click("Create", in: .sheet)
        let canvas = flare.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "New showed no stage (suite.canvas)")
        // A click with Select on the empty stage only gives it the keyboard.
        point(530, 380, on: canvas).click()
        flare.shot("loop-1-new")

        // 2. Rectangle and drag a rectangle from (100, 100) to (200, 180): Rectangle 1, keyed at 0 only.
        choose("Rectangle", flare)
        point(100, 100, on: canvas).press(forDuration: 0.1, thenDragTo: point(200, 180, on: canvas))
        let sidebar = flare.element("suite.sidebar")
        XCTAssert(sidebar.staticTexts[Self.lane].waitForExistence(timeout: 10), "the drag drew no \(Self.lane)")
        expectKeys([0], flare, "after the draw")
        flare.shot("loop-2-rectangle")

        // 3. Auto-key on: the recording ring shows.
        let autoKey = toolbar.buttons["flare.timeline.toggleAutoKey"]
        XCTAssert(autoKey.waitForExistence(timeout: 5) && autoKey.isEnabled, "Auto-key is missing or disabled")
        autoKey.click()
        XCTAssert(flare.element("flare.recording").waitForExistence(timeout: 5), "no recording ring with Auto-key on")
        flare.shot("loop-3-auto-key-on")

        // 4. Select, frame 24, drag the rectangle (centre (150, 140)) 200 points right: keys at 0 and 24.
        choose("Select", flare)
        scrub(to: 24, flare)
        point(150, 140, on: canvas).press(forDuration: 0.1, thenDragTo: point(350, 140, on: canvas))
        XCTAssert(waitFor { keys(Self.lane, flare).contains(24) }, "the drag at 24 left \(keys(Self.lane, flare).sorted())")
        expectKeys([0, 24], flare, "after the drag at 24")
        flare.shot("loop-4-keyed")

        // 5. Play/Pause, wait, Play/Pause on the transport: the playhead moves, then holds.
        let play = flare.element("flare.timeline.togglePlay")
        XCTAssert(play.waitForExistence(timeout: 5) && play.isEnabled, "no enabled Play (flare.timeline.togglePlay)")
        play.click()
        Thread.sleep(forTimeInterval: 0.5)
        play.click()
        let paused = frame(flare)
        XCTAssertNotEqual(paused, 24, "Play didn't play")
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(frame(flare), paused, "the second Play/Pause didn't pause")
        flare.shot("loop-5-played")

        // 6. The toolbar's Undo takes away only the key at 24; its Redo brings it back.
        click("flare.edit.undo", in: toolbar)
        XCTAssert(waitFor { !keys(Self.lane, flare).contains(24) }, "Undo left \(keys(Self.lane, flare).sorted())")
        expectKeys([0], flare, "after Undo")
        flare.shot("loop-6-undo")
        click("flare.edit.redo", in: toolbar)
        XCTAssert(waitFor { keys(Self.lane, flare).contains(24) }, "Redo left \(keys(Self.lane, flare).sorted())")
        expectKeys([0, 24], flare, "after Redo")
        flare.shot("loop-6-redo")

        // 7. The toolbar's Save: written to -FlareSaveTo with no panel, titled Untitled, not edited.
        click("flare.file.save", in: toolbar)
        XCTAssert(waitFor { FileManager.default.fileExists(atPath: file.path) }, "Save wrote no \(file.path)")
        expectSaved(flare)
        flare.shot("loop-7-saved")

        // 8. End, then File > Open Recent > Untitled.flare: back at 0 with keys at 0 and 24.
        flare.press(.end)
        XCTAssert(waitFor { frame(flare) == 47 }, "End gave \(String(describing: frame(flare)))")
        flare.app.menuBars.menuBarItems["File"].click()
        let recent = flare.app.menuBars.menuItems["Open Recent"]
        XCTAssert(recent.waitForExistence(timeout: 5), "File has no Open Recent")
        recent.hover()
        let item = recent.menuItems["Untitled.flare"]
        XCTAssert(item.waitForExistence(timeout: 5), "File > Open Recent doesn't list Untitled.flare")
        flare.shot("loop-8-open-recent", screen: true)
        item.click()
        XCTAssert(waitFor { frame(flare) == 0 }, "opening the file left the playhead at \(String(describing: frame(flare)))")
        XCTAssert(waitFor { keys(Self.lane, flare).contains(24) }, "the reopened lane reads \(keys(Self.lane, flare).sorted())")
        expectKeys([0, 24], flare, "after reopening")
        expectSaved(flare)
        flare.shot("loop-8-reopened")

        // 9. ⌘N, the sheet's Square preset and Create: a 1080 × 1080 document.
        flare.press(character: "n", .command)
        let sheet = flare.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 10), "⌘N showed no sheet")
        flare.click("Square", in: .sheet)
        for side in ["flare.new.width", "flare.new.height"] {
            let field = sheet.descendants(matching: .any)[side]
            XCTAssert(waitFor { field.value as? String == "1080" }, "Square left \(side) at \(String(describing: field.value))")
        }
        flare.shot("loop-9-new-square")
        flare.click("Create", in: .sheet)
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Create left the sheet open")
        let artboard = flare.element("suite.canvas.artboard")
        XCTAssert(artboard.waitForExistence(timeout: 10), "Create showed no artboard (suite.canvas.artboard)")
        let ratio = artboard.frame.width > 0 ? artboard.frame.height / artboard.frame.width : 0
        XCTAssertEqual(ratio, 1, accuracy: 0.01, "the artboard isn't 1080 × 1080")
        XCTAssert(waitFor { keys(Self.lane, flare).isEmpty }, "the new document still has \(Self.lane)")
        flare.shot("loop-9-square")

        // 10. File > Open Recent > Untitled.flare again: the saved keys at 0 and 24 are still there.
        flare.app.menuBars.menuBarItems["File"].click()
        XCTAssert(recent.waitForExistence(timeout: 5), "File has no Open Recent")
        recent.hover()
        XCTAssert(item.waitForExistence(timeout: 5), "File > Open Recent doesn't list Untitled.flare")
        item.click()
        XCTAssert(waitFor { keys(Self.lane, flare).contains(24) }, "the reopened lane reads \(keys(Self.lane, flare).sorted())")
        expectKeys([0, 24], flare, "after reopening past the sheet")
        expectSaved(flare)
        flare.shot("loop-10-reopened")
    }

    /// The lane's keys are exactly `want`.
    @MainActor private func expectKeys(_ want: Set<Int>, _ flare: Journey, _ when: String) {
        XCTAssert(waitFor { keys(Self.lane, flare) == want },
                  "\(Self.lane)'s lane reads \(keys(Self.lane, flare).sorted()) \(when), not \(want.sorted())")
    }

    /// The window reads "Untitled" with no edited dot (`flare.file` reads "Saved").
    @MainActor private func expectSaved(_ flare: Journey) {
        let window = flare.app.windows.firstMatch, status = flare.element("flare.file")
        XCTAssert(waitFor { window.title == "Untitled" }, "the window is titled \(window.title), not Untitled")
        XCTAssert(waitFor { status.label == "Saved" }, "flare.file reads \(status.label), not Saved")
    }

    /// Clicks the palette's `title` button (`suite.tools`); it reads selected.
    @MainActor private func choose(_ title: String, _ flare: Journey) {
        let button = flare.element("suite.tools").buttons[title]
        XCTAssert(button.waitForExistence(timeout: 5), "no \(title) in the palette (suite.tools)")
        button.click()
        XCTAssert(waitFor { button.isSelected }, "clicking \(title) didn't select it")
    }

    /// Clicks the toolbar button `identifier` once it is enabled.
    @MainActor private func click(_ identifier: String, in toolbar: XCUIElement) {
        let button = toolbar.buttons[identifier]
        XCTAssert(waitFor { button.exists && button.isEnabled }, "no enabled \(identifier) in the toolbar")
        button.click()
    }

    /// The frames of the keys on the lane named `name`: its key children, else the frames its value lists.
    @MainActor private func keys(_ name: String, _ flare: Journey) -> Set<Int> {
        let lanes = flare.element("flare.timeline").descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ AND elementType != %d", name, XCUIElement.ElementType.button.rawValue))
        var frames = Set<Int>()
        for lane in lanes.allElementsBoundByIndex {
            let children = lane.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Key at frame '"))
            for key in children.allElementsBoundByIndex {
                if let frame = Int(key.label.dropFirst("Key at frame ".count).prefix { $0.isNumber }) { frames.insert(frame) }
            }
            guard frames.isEmpty, let value = lane.value as? String,
                  let listed = value.range(of: "keyframes at ") ?? value.range(of: "keyframe at ") else { continue }
            for part in value[listed.upperBound...].split(separator: ",") {
                if let frame = Int(part.trimmingCharacters(in: .whitespaces)) { frames.insert(frame) }
            }
        }
        return frames
    }

    /// The screen point of the scene point (`x`, `y`): the artboard's corner plus the point at its fit scale.
    @MainActor private func point(_ x: Double, _ y: Double, on canvas: XCUIElement) -> XCUICoordinate {
        let scale = canvas.frame.width / Self.sceneWidth
        return canvas.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x * scale, dy: y * scale))
    }

    /// Drags the playhead on the Frame Ruler from 0 to `target`.
    @MainActor private func scrub(to target: Int, _ flare: Journey) {
        let ruler = flare.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        ruler.coordinate(withNormalizedOffset: .zero).withOffset(x(frame: 0, ruler))
            .press(forDuration: 0.1, thenDragTo: ruler.coordinate(withNormalizedOffset: .zero).withOffset(x(frame: target, ruler)))
        XCTAssert(waitFor { frame(flare) == target }, "the frame is \(String(describing: frame(flare))) after the scrub")
    }

    /// The frame the readout names ("24 / 48" is 24); nil when it names none.
    @MainActor private func frame(_ flare: Journey) -> Int? {
        let readout = flare.element("flare.timeline.frame")
        guard readout.exists else { return nil }
        return Int(readout.label.prefix { $0.isNumber })
    }

    /// The offset of `frame` from the ruler's top-left corner, at the ruler's middle.
    @MainActor private func x(frame: Int, _ ruler: XCUIElement) -> CGVector {
        let frameWidth = (ruler.frame.width - 24) / Self.lastFrame
        return CGVector(dx: 8 + Double(frame) * frameWidth, dy: ruler.frame.height / 2)
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
