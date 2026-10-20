// LibraryJourneyTests+Crop.swift: J6, crop and straighten in the loupe
// (packet docs/blueprints/library/features/crop.md, Journey steps). Steps 1
// to 9 run on the `shoot` fixture's fakes (F) with `-LibraryTestValues`, so
// the loupe photo's value (`library.loupe.photo`, "full 2048×1365 3f9a… 100%
// No stars") carries the picture's size. The crop area's identifiers: the
// frame `library.crop.frame` (its value "4000 × 4000 at 1000, 0"), the chips
// `library.crop.aspect.<title>` ("library.crop.aspect.1:1"), Straighten
// `library.crop.straighten`, and `library.crop.auto`, `.apply`, `.cancel`.
//
// Written before its views (lead.md, contract rule 13): CR-5 wrote it
// skipped, CR-6 dropped the skip for the (F) run, CR-7 adds the (L) run and
// step 10. The frame's handles are `library.crop.handle.<name>`
// (`library.crop.handle.topLeft`). Each step takes the window and a shot suffix so the (L) run can
// walk the same steps on real files.
//
// The (L) run walks steps 1 to 5 and 9 on the 24 JPEGs `LibraryFiles.writeShoot`
// writes, imported on launch, its shots ending `-live`; at 5° its 1:1 frame
// is 3545 px. Step 10 then crops IMG_0001 again, waits until the catalog is
// saved (`library.catalog` reads "saved", or `catalog.json` holds the crop),
// and relaunches on the same `-LibraryCatalogDir`: the cell and the loupe are
// still square and R shows the stored 3545 px frame at 5°.
import XCTest

extension LibraryJourneyTests {
    static let cropFake = ["-LibraryFixture", "shoot", "-LibraryTestValues"]
    static let cropAspects = ["Original", "Free", "1:1", "4:5", "3:2", "16:9"]

    /// J6: Photo > Crop shows the frame, chips and Straighten; 1:1, a typed
    /// angle and Return store one "Crop" step; a drag and Escape record
    /// nothing; the arrows nudge the frame; Auto levels; Reset Crop clears it.
    @MainActor func testCropAndStraighten() throws {
        let library = cropOpen(Self.cropFake, suffix: "")
        cropSquare(library)
        cropStraighten(library, suffix: "", width: nil)
        cropApply(library, suffix: "")
        cropCancelDrag(library)
        cropChipWidths(library)
        cropNudge(library)
        cropAuto(library, live: false)
        cropReset(library)
        library.app.terminate()
        try cropLive()
    }

    /// The (L) run: steps 1 to 5 and 9 on real files, then step 10.
    @MainActor private func cropLive() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        let arguments = ["-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
                         "-LibraryImportOnLaunch", "-LibraryTestValues"]
        // A live render of a 6000 × 4000 photo takes seconds in a debug build: render waits stretch.
        CropRun.slack = 6
        defer { CropRun.slack = 1 }
        let library = cropOpen(arguments, suffix: "-live")
        cropSquare(library)
        cropStraighten(library, suffix: "-live", width: Self.cropLiveWidth)
        cropApply(library, suffix: "-live")
        cropCancelDrag(library)
        cropReset(library)
        cropRelaunch(library, catalog: catalog)
    }

    /// The live 1:1 frame's side at 5° on a 6000 × 4000 photo (MJ6L).
    private static let cropLiveWidth = 3545

    // MARK: - Steps

    /// Step 1: by name, IMG_0001 in the loupe, the Develop tab, the photo clicked, R: the frame
    /// reads the whole photo, the chips, Straighten at 0, Auto, Apply, Cancel,
    /// and Photo's item reads "Done Cropping".
    @MainActor private func cropOpen(_ arguments: [String], suffix: String) -> Journey {
        let library = Journey("Library", self, arguments: arguments)
        cropSortByName(library)
        let first = cropCell("IMG_0001", library)
        XCTAssert(first.waitForExistence(timeout: 10), "no grid cell for IMG_0001")
        first.doubleClick()
        XCTAssert(library.element("library.loupe").waitForExistence(timeout: 10), "double-click didn't open the loupe")
        let tab = library.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Develop'")).firstMatch
        XCTAssert(tab.waitForExistence(timeout: 5), "the inspector has no Develop tab")
        tab.click()
        cropKeyR(library)
        let frame = library.element("library.crop.frame")
        XCTAssert(frame.waitForExistence(timeout: 5), "R showed no crop frame (library.crop.frame)")
        library.shot("crop\(suffix)")
        XCTAssert(Self.cropText(frame).hasPrefix("6000 × 4000"), "the frame reads \(Self.cropText(frame))")
        for aspect in Self.cropAspects {
            XCTAssert(library.element("library.crop.aspect.\(aspect)").exists, "no \(aspect) chip (library.crop.aspect.\(aspect))")
        }
        let straighten = library.element("library.crop.straighten")
        XCTAssert(straighten.exists, "no Straighten (library.crop.straighten)")
        XCTAssertEqual(Self.cropNumber(straighten), 0, "Straighten isn't 0 on a new draft")
        for control in ["auto", "apply", "cancel"] {
            XCTAssert(library.element("library.crop.\(control)").exists, "no library.crop.\(control)")
        }
        let photo = library.app.menuBars.firstMatch.menuBarItems["Photo"]
        photo.click()
        XCTAssert(photo.menuItems["Done Cropping"].waitForExistence(timeout: 3), "Photo's crop item doesn't read Done Cropping")
        library.press(.escape)
        return library
    }

    /// Step 2: the 1:1 chip frames 4000 × 4000.
    @MainActor private func cropSquare(_ library: Journey) {
        library.element("library.crop.aspect.1:1").click()
        let frame = library.element("library.crop.frame")
        XCTAssert(cropWait(3) { Self.cropText(frame).hasPrefix("4000 × 4000") }, "1:1 framed \(Self.cropText(frame))")
    }

    /// Step 3: 5 typed into Straighten shrinks the frame; (L) to `width` (±1).
    @MainActor private func cropStraighten(_ library: Journey, suffix: String, width: Int?) {
        let straighten = library.element("library.crop.straighten")
        straighten.click()
        library.press(character: "a", .command)
        library.app.typeText("5")
        library.press(.return)
        let frame = library.element("library.crop.frame")
        XCTAssert(cropWait(3) { Self.cropNumber(straighten) == 5 }, "Straighten reads \(Self.cropText(straighten)), not 5.0")
        library.shot("crop-straighten\(suffix)")
        let measured = Self.cropFrameWidth(frame)
        XCTAssertLessThan(measured, 4000, "the frame didn't shrink at 5°: \(Self.cropText(frame))")
        if let width { XCTAssertEqual(Double(measured), Double(width), accuracy: 1, "the 1:1 frame at 5°") }
    }

    /// Step 4: Return on the photo stores the crop as "Crop"; the loupe is square, also after reopening.
    @MainActor private func cropApply(_ library: Journey, suffix: String) {
        library.element("library.loupe.photo").click()
        library.press(.return)
        XCTAssert(library.element("library.crop.frame").waitForNonExistence(timeout: 3), "Return left the frame up")
        library.shot("crop-applied\(suffix)")
        XCTAssert(cropWait(5) { self.cropLoupeRatio(library) == 1 }, "the loupe isn't square: \(cropLoupeValue(library))")
        library.press(.escape)
        cropCell("IMG_0001", library).doubleClick()
        XCTAssert(cropWait(5) { self.cropLoupeRatio(library) == 1 }, "reopened, the loupe isn't square: \(cropLoupeValue(library))")
        cropExpectMenu("Edit", "Undo", "Undo Crop", library)
    }

    /// Step 5: Undo, then a draft dragged 200 pt in and cancelled: the loupe
    /// is 3:2 again and Redo still reads "Redo Crop".
    @MainActor private func cropCancelDrag(_ library: Journey) {
        library.press(character: "z", .command)
        XCTAssert(cropWait(5) { abs(self.cropLoupeRatio(library) - 1.5) < 0.01 }, "Undo left \(cropLoupeValue(library))")
        cropKeyR(library)
        let frame = library.element("library.crop.frame")
        XCTAssert(frame.waitForExistence(timeout: 5), "R showed no crop frame")
        let corner = frame.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        corner.press(forDuration: 0.1, thenDragTo: corner.withOffset(CGVector(dx: 200, dy: 200)))
        library.press(.escape)
        XCTAssert(frame.waitForNonExistence(timeout: 3), "Escape left the frame up")
        XCTAssert(cropWait(5) { abs(self.cropLoupeRatio(library) - 1.5) < 0.01 }, "Cancel left \(cropLoupeValue(library))")
        cropExpectMenu("Edit", "Redo", "Redo Crop", library)
    }

    /// Step 6: the six chips are one width (±0.5 pt).
    @MainActor private func cropChipWidths(_ library: Journey) {
        cropKeyR(library)
        XCTAssert(library.element("library.crop.frame").waitForExistence(timeout: 5), "R showed no crop frame")
        let widths = Self.cropAspects.map { library.element("library.crop.aspect.\($0)").frame.width }
        let spread = (widths.max() ?? 0) - (widths.min() ?? 0)
        XCTAssertLessThanOrEqual(spread, 0.5, "the chips' widths differ: \(widths)")
        library.press(.escape)
    }

    /// Step 7: on 1:1, Right three times nudges the frame 3 px, Shift-Right 10 more.
    @MainActor private func cropNudge(_ library: Journey) {
        cropKeyR(library)
        let frame = library.element("library.crop.frame")
        XCTAssert(frame.waitForExistence(timeout: 5), "R showed no crop frame")
        library.element("library.crop.aspect.1:1").click()
        frame.click()
        for _ in 0..<3 { library.press(.rightArrow) }
        XCTAssert(cropWait(3) { Self.cropText(frame).hasSuffix("at 1003, 0") }, "Right ×3 framed \(Self.cropText(frame))")
        library.press(.rightArrow, .shift)
        XCTAssert(cropWait(3) { Self.cropText(frame).hasSuffix("at 1013, 0") }, "Shift-Right framed \(Self.cropText(frame))")
        library.press(.escape)
    }

    /// Step 8: Auto turns Straighten to the fake's 2.5; `live` before CR-10, Auto is off with its reason.
    @MainActor private func cropAuto(_ library: Journey, live: Bool) {
        cropKeyR(library)
        let auto = library.element("library.crop.auto")
        XCTAssert(auto.waitForExistence(timeout: 5), "no Auto (library.crop.auto)")
        if live {
            XCTAssertFalse(auto.isEnabled, "Auto is on with no leveler")
        } else {
            auto.click()
            let straighten = library.element("library.crop.straighten")
            XCTAssert(cropWait(3) { Self.cropNumber(straighten) == 2.5 }, "Auto set Straighten to \(Self.cropText(straighten))")
        }
        library.press(.escape)
    }

    /// Step 9: IMG_0002 cropped 1:1, then Photo > Reset Crop: 3:2 again as
    /// "Reset Crop"; on the uncropped photo Reset Crop is off and says why.
    @MainActor private func cropReset(_ library: Journey) {
        library.press(.escape)
        cropCell("IMG_0002", library).doubleClick()
        XCTAssert(library.element("library.loupe").waitForExistence(timeout: 10), "IMG_0002 didn't open in the loupe")
        cropKeyR(library)
        XCTAssert(library.element("library.crop.frame").waitForExistence(timeout: 5), "R showed no crop frame")
        library.element("library.crop.aspect.1:1").click()
        library.element("library.loupe.photo").click()
        library.press(.return)
        XCTAssert(cropWait(5) { self.cropLoupeRatio(library) == 1 }, "IMG_0002 isn't square: \(cropLoupeValue(library))")
        let photo = library.app.menuBars.firstMatch.menuBarItems["Photo"]
        photo.click()
        let reset = photo.menuItems["Reset Crop"]
        XCTAssert(reset.waitForExistence(timeout: 3), "the Photo menu has no Reset Crop")
        reset.click()
        XCTAssert(cropWait(5) { abs(self.cropLoupeRatio(library) - 1.5) < 0.01 }, "Reset Crop left \(cropLoupeValue(library))")
        cropExpectMenu("Edit", "Undo", "Undo Reset Crop", library)
        photo.click()
        XCTAssert(reset.waitForExistence(timeout: 3), "the Photo menu has no Reset Crop")
        XCTAssertFalse(reset.isEnabled, "Photo > Reset Crop is on for an uncropped photo")
        library.press(.escape)
        let reason = "This photo isn't cropped."
        let probe = library.element("library.controls")
        XCTAssert(probe.waitForExistence(timeout: 5) && probe.label.contains(reason),
                  "library.controls doesn't say \"\(reason)\"")
    }

    /// Step 10 (L): IMG_0001 cropped 1:1 at 5° and applied; once the catalog
    /// is saved, a relaunch on the same catalog shows its cell and loupe
    /// square, and R shows the stored 3545 px frame at 5°.
    @MainActor private func cropRelaunch(_ library: Journey, catalog: URL) {
        library.press(.escape)
        let first = cropCell("IMG_0001", library)
        XCTAssert(first.waitForExistence(timeout: 10), "no grid cell for IMG_0001")
        first.doubleClick()
        XCTAssert(library.element("library.loupe").waitForExistence(timeout: 10), "IMG_0001 didn't open in the loupe")
        cropKeyR(library)
        XCTAssert(library.element("library.crop.frame").waitForExistence(timeout: 5), "R showed no crop frame")
        cropSquare(library)
        cropStraighten(library, suffix: "-live-again", width: Self.cropLiveWidth)
        library.element("library.loupe.photo").click()
        library.press(.return)
        XCTAssert(library.element("library.crop.frame").waitForNonExistence(timeout: 3), "Return left the frame up")
        XCTAssert(cropWait(10) { self.cropLoupeRatio(library) == 1 }, "the loupe isn't square: \(cropLoupeValue(library))")
        let readout = library.element("library.catalog")
        let saved = cropWait(15) {
            if readout.exists { return Self.cropText(readout) == "saved" }
            return Self.cropSaved(in: catalog)
        }
        XCTAssert(saved, "the catalog never read saved (library.catalog: \(Self.cropText(readout)))")
        library.app.terminate()

        let again = Journey("Library", self, arguments: ["-LibraryCatalogDir", catalog.path, "-LibraryTestValues"])
        cropSortByName(again)
        let cell = cropCell("IMG_0001", again)
        XCTAssert(cell.waitForExistence(timeout: 10), "no grid cell for IMG_0001 after the relaunch")
        XCTAssert(cropWait(10) { Self.cropRatio(Self.cropText(cell)) == 1 }, "relaunched, IMG_0001's cell reads \(Self.cropText(cell))")
        again.shot("crop-relaunched-live")
        cell.doubleClick()
        XCTAssert(again.element("library.loupe").waitForExistence(timeout: 10), "IMG_0001 didn't open in the loupe")
        XCTAssert(cropWait(10) { self.cropLoupeRatio(again) == 1 }, "relaunched, the loupe isn't square: \(cropLoupeValue(again))")
        cropKeyR(again)
        let frame = again.element("library.crop.frame")
        XCTAssert(frame.waitForExistence(timeout: 5), "R showed no crop frame after the relaunch")
        let measured = Self.cropFrameWidth(frame)
        XCTAssertEqual(Double(measured), Double(Self.cropLiveWidth), accuracy: 1, "relaunched, the frame reads \(Self.cropText(frame))")
        let straighten = again.element("library.crop.straighten")
        XCTAssert(cropWait(3) { Self.cropNumber(straighten) == 5 }, "relaunched, Straighten reads \(Self.cropText(straighten))")
        again.press(.escape)
        again.app.terminate()
    }

    /// Whether `catalog.json` in `catalog` stores a crop on IMG_0001.
    private static func cropSaved(in catalog: URL) -> Bool {
        let file = catalog.appending(path: "catalog.json")
        guard let data = try? Data(contentsOf: file),
            let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let photos = top["photos"] as? [[String: Any]]
        else { return false }
        for photo in photos {
            let id = photo["id"] as? String ?? ""
            let develop = photo["develop"] as? [String: Any] ?? [:]
            if id.contains("IMG_0001"), develop["crop"] != nil { return true }
        }
        return false
    }

    // MARK: - Helpers

    /// R with the loupe photo focused: a click on an inspector tab or chip
    /// takes the keys, and R goes only to the grid or the loupe.
    @MainActor private func cropKeyR(_ library: Journey) {
        let photo = library.element("library.loupe.photo")
        if photo.waitForExistence(timeout: 3), photo.isHittable {
            photo.click()
        } else {
            library.element("library.loupe").click()
        }
        library.press(character: "r")
    }

    /// Polls `condition` every tenth of a second for up to `seconds` times `CropRun.slack`.
    @MainActor private func cropWait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds * CropRun.slack)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return condition()
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func cropCell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }

    /// Waits for the window and IMG_0024's cell, then View > Sort By > Name.
    @MainActor private func cropSortByName(_ library: Journey) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(cropCell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        let byName = sort.menuItems["Name"]
        XCTAssert(byName.waitForExistence(timeout: 3), "View > Sort By has no Name")
        byName.click()
    }

    /// `menu`'s first item starting `prefix` reads `title` ("Undo Crop").
    @MainActor private func cropExpectMenu(_ menu: String, _ prefix: String, _ title: String, _ library: Journey) {
        let bar = library.app.menuBars.firstMatch.menuBarItems[menu]
        bar.click()
        let item = bar.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", prefix)).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the \(menu) menu has no \(prefix)")
        XCTAssertEqual(item.title, title, "\(menu)'s \(prefix)")
        library.press(.escape)
    }

    /// The loupe photo's value ("full 2048×1365 3f9a… 100% No stars").
    @MainActor private func cropLoupeValue(_ library: Journey) -> String {
        (library.element("library.loupe.photo").value as? String) ?? ""
    }

    /// Width over height of the loupe value's "W×H", to two places; NaN without one.
    @MainActor private func cropLoupeRatio(_ library: Journey) -> Double {
        Self.cropRatio(cropLoupeValue(library))
    }

    /// Width over height of the first "W×H" in `text` ("ready 640×640 No stars"), to two places; NaN without one.
    private static func cropRatio(_ text: String) -> Double {
        for word in text.split(separator: " ") {
            let sides = word.split(separator: "×").compactMap { Double($0) }
            if sides.count == 2, sides[1] > 0 { return (sides[0] / sides[1] * 100).rounded() / 100 }
        }
        return .nan
    }

    /// The frame value's width: the first number of "3545 × 3545 at …"; 0 without one.
    @MainActor private static func cropFrameWidth(_ frame: XCUIElement) -> Int {
        cropText(frame).split(separator: " ").first.flatMap { Int($0) } ?? 0
    }

    /// What an element reads: its value, else its label.
    @MainActor private static func cropText(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// The first number an element reads ("5.0°" is 5); nil reads as NaN.
    @MainActor private static func cropNumber(_ element: XCUIElement) -> Double {
        let words = cropText(element).split(whereSeparator: { !"+-.0123456789".contains($0) })
        return words.lazy.compactMap { Double($0) }.first ?? .nan
    }
}

/// How many times longer `cropWait` polls: 1 on the fakes, more on live renders.
@MainActor private enum CropRun {
    static var slack: TimeInterval = 1
}
