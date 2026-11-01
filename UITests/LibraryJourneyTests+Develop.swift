// LibraryJourneyTests+Develop.swift: J5, the inspector's Develop tab (packet
// docs/blueprints/library/features/develop.md, Journey steps). Its own
// XCTestCase class, like +Shell.swift. Steps 1 to 9 and 11 run on the `shoot`
// fixture's fakes (F); the live pass (L) runs steps 1 to 10 on the 24 JPEGs
// `LibraryFiles.writeShoot` writes, imported on launch, its shots ending
// `-live`. Every launch passes `-LibraryTestValues`, so the loupe photo's
// value (repeated as the label of `library.loupe.value`, "full 2048×1365 3f9a… 100% No stars") carries
// the render's checksum, 16 hex digits. Rows are `library.develop.<slider>`
// (`library.develop.exposure`), the histogram readout
// `library.develop.histogram` with "mean 0.…" in its value.
//
// Written before its code (lead.md, contract rule 13, DV-7): each step started
// with `throw XCTSkip("waits on DV-n")`, and the task named there dropped it.
// DV-10 enabled (F) steps 1 and 11; DV-13 enabled (F) steps 2 to 9 and the (L)
// pass with step 10. The window publishes no `library.catalog` readout, so step
// 10 reads "saved" from disk, as J8 does: `catalog.json` holds the edit. A
// skipped step is noted and the walk goes on; the test then skips with every
// step's reason.
import XCTest

final class LibraryDevelopJourneyTests: XCTestCase {
    static let fake = ["-LibraryFixture", "shoot", "-LibraryTestValues"]
    private var library: Journey?
    private var original = ""
    private var skipped: [String] = []

    /// J5: sliders, curve, levels, Show Original, copy, paste, sync and reset
    /// from the Develop tab, each one named undo step, and the error state.
    @MainActor func testDevelopSlidersAndHistogram() throws {
        skipped = []
        try step("1") { try self.openDevelop(Self.fake, suffix: "") }
        try step("2") { try self.dragExposure(suffix: "") }
        try step("3") { try self.stepContrast() }
        try step("4") { try self.undoContrast() }
        try step("5") { try self.showOriginal(suffix: "") }
        try step("6") { try self.editCurveAndLevels(suffix: "") }
        try step("7") { try self.copyAndPaste(suffix: "") }
        try step("8") { try self.sync(suffix: "") }
        try step("9") { try self.reset() }
        library?.app.terminate()
        try step("11") { try self.errorState() }
        try step("L") { try self.livePass() }
        if !skipped.isEmpty { throw XCTSkip(skipped.joined(separator: "; ")) }
    }

    /// Runs `body`; a skip it throws is noted with `name` and the walk goes on.
    @MainActor private func step(_ name: String, _ body: () throws -> Void) throws {
        do { try body() } catch let skip as XCTSkip {
            skipped.append("step \(name): \(skip.message ?? "skipped")")
        }
    }

    // MARK: - Steps

    /// Step 1: by name, IMG_0001 in the loupe, the Develop tab: every row at 0, the curve, the levels.
    @MainActor private func openDevelop(_ arguments: [String], suffix: String, imports: Int? = nil) throws {
        let library = Journey("Library", self, arguments: arguments)
        self.library = library
        if let imports {
            // The launch import fills the grid for seconds on a slow runner; a double-click on a cell
            // that is still moving misses it. All Photos counts every file once the import is done.
            let badge = library.element("suite.sidebar").descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@ OR value == %@", "\(imports)", "\(imports)")).firstMatch
            XCTAssert(badge.waitForExistence(timeout: 60), "the import never reached \(imports) photos")
        }
        sortByName(library)
        let first = cell("IMG_0001", library)
        XCTAssert(first.waitForExistence(timeout: 10), "no grid cell for IMG_0001")
        first.doubleClick()
        let loupe = library.element("library.loupe")
        // A loaded runner sometimes drops a synthesized double-click while the grid settles after the
        // sort (journeys run 41279040508: three suites missed the loupe this way); a second one, as a
        // person would, opens it.
        if !loupe.waitForExistence(timeout: 5), first.exists { first.doubleClick() }
        XCTAssert(loupe.waitForExistence(timeout: 10), "double-click didn't open the loupe")
        developTab(library)
        let histogram = library.element("library.develop.histogram")
        XCTAssert(histogram.waitForExistence(timeout: 5), "no histogram (library.develop.histogram)")
        XCTAssert(wait(5) { Self.text(histogram).hasPrefix("mean 0.") }, "the histogram reads \(Self.text(histogram))")
        library.shot("develop\(suffix)")
        for slider in ["Exposure", "Contrast", "Highlights", "Shadows", "Whites", "Blacks",
                       "Temperature", "Tint", "Vibrance", "Saturation"] {
            let row = self.row(slider, library)
            XCTAssert(row.waitForExistence(timeout: 3), "no \(slider) row (library.develop.\(slider.lowercased()))")
            XCTAssertEqual(Self.number(row), 0, "\(slider) isn't 0 on a new photo")
        }
        XCTAssert(library.element("library.develop.curve").exists, "no curve (library.develop.curve)")
        XCTAssert(library.element("library.develop.curve.point2").exists, "the curve hasn't two points")
        XCTAssertFalse(library.element("library.develop.curve.point3").exists, "a new photo's curve has a third point")
        for field in ["Black Point", "Midtones", "White Point", "Output Black", "Output White"] {
            XCTAssert(inspectorItem(field, library).exists, "no LEVELS row \(field)")
        }
        original = try settledChecksum(library)
    }

    /// Step 2: dragging Exposure right is one step "Exposure" that re-renders and lifts the histogram.
    @MainActor private func dragExposure(suffix: String) throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        let exposure = row("Exposure", library)
        let mean = Self.mean(library.element("library.develop.histogram"))
        exposure.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: exposure.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssert(wait(5) { Self.number(exposure) > 0 }, "Exposure reads \(Self.text(exposure)) after the drag")
        XCTAssert(wait(5) { (try? self.checksum(library)) != self.original }, "the loupe didn't re-render")
        XCTAssertGreaterThan(Self.mean(library.element("library.develop.histogram")), mean, "the histogram's mean didn't rise")
        library.shot("develop-exposure\(suffix)")
        expectUndo("Undo Exposure", library)
        library.press(character: "z", .command)
        XCTAssert(wait(5) { Self.number(exposure) == 0 }, "one Undo left Exposure at \(Self.text(exposure))")
        library.press(character: "z", [.command, .shift])
    }

    /// Step 3: Right three times, then Shift-Right, on Contrast: 3, then 13.
    @MainActor private func stepContrast() throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        let contrast = row("Contrast", library)
        // A click opens the row's typing field; Return closes it and keeps the focus for the arrows.
        contrast.click()
        library.press(.return)
        for _ in 0..<3 { library.press(.rightArrow) }
        XCTAssert(wait(3) { Self.number(contrast) == 3 }, "Contrast reads \(Self.text(contrast)), not 3")
        library.press(.rightArrow, .shift)
        XCTAssert(wait(3) { Self.number(contrast) == 13 }, "Contrast reads \(Self.text(contrast)), not 13")
    }

    /// Step 4: "Undo Contrast" undoes one key step and redraws the loupe.
    @MainActor private func undoContrast() throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        let before = try settledChecksum(library)
        expectUndo("Undo Contrast", library)
        library.press(character: "z", .command)
        let contrast = row("Contrast", library)
        XCTAssert(wait(3) { Self.number(contrast) == 3 }, "after Undo Contrast reads \(Self.text(contrast)), not 3")
        XCTAssert(wait(5) { (try? self.checksum(library)) != before && self.loupeQuality(library) == "full" },
                  "Undo Contrast didn't redraw the loupe")
    }

    /// Step 5: Show Original draws step 1's picture without an undo step; again brings the edit back.
    @MainActor private func showOriginal(suffix: String) throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        let developed = try settledChecksum(library)
        let button = library.element("library.develop.original")
        XCTAssert(button.waitForExistence(timeout: 3), "no Show Original (library.develop.original)")
        button.click()
        XCTAssert(wait(5) { (try? self.checksum(library)) == self.original }, "Show Original isn't step 1's picture")
        library.shot("develop-original\(suffix)")
        expectUndo("Undo Contrast", library)
        button.click()
        XCTAssert(wait(5) { (try? self.checksum(library)) == developed }, "the developed picture didn't come back")
    }

    /// Step 6: a curve point dragged up 40 pt is "Undo Curve"; the Midtones handle dragged is "Undo Levels".
    @MainActor private func editCurveAndLevels(suffix: String) throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        let before = try checksum(library)
        // Step 5's Show Original click scrolls the list down; a drag doesn't scroll, so on a short screen
        // the curve's middle would sit under the Info/Develop switch.
        let curve = library.element("library.develop.curve")
        scrollDevelop(toShow: curve, library)
        let middle = curve.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        middle.press(forDuration: 0.1, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: -40)))
        XCTAssert(wait(5) { (try? self.checksum(library)) != before }, "the curve didn't re-render the loupe")
        library.shot("develop-curve\(suffix)")
        expectUndo("Undo Curve", library)
        // The Midtones handle (LevelsHandles) dragged left brightens: one "Levels" step.
        let handle = inspectorItem("Midtones", library)
        scrollDevelop(toShow: handle, library)
        let midtones = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        midtones.press(forDuration: 0.1, thenDragTo: midtones.withOffset(CGVector(dx: -20, dy: 0)))
        expectUndo("Undo Levels", library)
    }

    /// Step 7: copy IMG_0001's settings, paste on IMG_0002 to IMG_0004 as one step, undo all three.
    @MainActor private func copyAndPaste(suffix: String) throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        let exposure = Self.number(row("Exposure", library))
        library.element("library.loupe.photo").click()
        library.press(character: "c", [.command, .shift])
        library.press(.escape)
        cell("IMG_0002", library).click()
        XCUIElement.perform(withKeyModifiers: .shift) { cell("IMG_0004", library).click() }
        library.press(character: "v", [.command, .shift])
        library.shot("develop-pasted\(suffix)")
        expectUndo("Undo Paste Settings", library)
        cell("IMG_0003", library).doubleClick()
        XCTAssert(wait(5) { Self.number(self.row("Exposure", library)) == exposure }, "IMG_0003's Exposure isn't IMG_0001's")
        library.press(.escape)
        library.press(character: "z", .command)
        cell("IMG_0003", library).doubleClick()
        XCTAssert(wait(5) { Self.number(self.row("Exposure", library)) == 0 }, "one Undo didn't put IMG_0003 back")
    }

    /// Step 8: IMG_0001 to IMG_0006 selected, Sync from IMG_0001 is one step and leaves no row Mixed.
    @MainActor private func sync(suffix: String) throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        library.press(.escape)
        cell("IMG_0001", library).click()
        XCUIElement.perform(withKeyModifiers: .shift) { cell("IMG_0006", library).click() }
        let button = library.element("library.develop.sync")
        XCTAssert(button.waitForExistence(timeout: 3), "no Sync (library.develop.sync)")
        XCTAssertEqual(button.label, "Sync from IMG_0001", "the Sync button's title")
        button.click()
        library.shot("develop-synced\(suffix)")
        XCTAssert(wait(3) { !Self.text(self.row("Exposure", library)).contains("Mixed") }, "Exposure still reads Mixed")
        expectUndo("Undo Sync Settings", library)
    }

    /// Step 9: Reset Exposure from the row's menu, then TONE's Reset.
    @MainActor private func reset() throws {
        let library = try XCTUnwrap(self.library, "step 1 opened no window")
        cell("IMG_0001", library).doubleClick()
        // Step 8's Sync click scrolled the list down; a right click doesn't scroll back.
        scrollDevelop(toShow: row("Exposure", library), library)
        row("Exposure", library).rightClick()
        let item = library.app.menuItems["Reset Exposure"]
        XCTAssert(item.waitForExistence(timeout: 3), "the Exposure row's menu has no Reset Exposure")
        item.click()
        expectUndo("Undo Reset Exposure", library)
        let toneReset = library.element("suite.inspector.section.tone.reset")
        XCTAssert(toneReset.waitForExistence(timeout: 3), "TONE has no Reset (suite.inspector.section.tone.reset)")
        XCTAssertEqual(toneReset.label, "Reset Tone", "TONE's Reset label")
        scrollDevelop(toShow: toneReset, library)
        toneReset.click()
        for slider in ["Exposure", "Contrast", "Highlights", "Shadows", "Whites", "Blacks"] {
            XCTAssertEqual(Self.number(row(slider, library)), 0, "TONE's Reset left \(slider) set")
        }
        expectUndo("Undo Reset Tone", library)
    }

    /// Step 10 (L): Exposure +1 survives a relaunch with the same picture, and the grid redraws the cell.
    @MainActor private func relaunch(_ arguments: [String], catalog: URL) throws {
        var library = try XCTUnwrap(self.library, "step 1 opened no window")
        let exposure = row("Exposure", library)
        let before = try checksum(library)
        exposure.click()
        library.press(character: "a", .command)
        library.app.typeText("1")
        library.press(.return)
        XCTAssert(wait(5) { Self.number(exposure) == 1 }, "Exposure reads \(Self.text(exposure)), not 1")
        XCTAssert(wait(5) { (try? self.checksum(library)) != before && self.loupeQuality(library) == "full" },
                  "Exposure +1 didn't re-render the loupe")
        let developed = try checksum(library)
        XCTAssert(wait(10) { Self.savedExposure(in: catalog, of: "IMG_0001") == 1 }, "catalog.json never held Exposure +1")
        library.app.terminate()
        library = Journey("Library", self, arguments: ["-LibraryCatalogDir", catalog.path, "-LibraryTestValues"])
        self.library = library
        sortByName(library)
        cell("IMG_0001", library).doubleClick()
        developTab(library)
        XCTAssert(wait(5) { Self.number(self.row("Exposure", library)) == 1 }, "Exposure didn't survive the relaunch")
        // The first render after a launch can land on the CPU route while the GPU's pipelines still compile,
        // and the test checksum depends on the route (CPU pixels, or the base and its GPU program). Reopening
        // draws again on the route that is ready, so the same picture reads the same once both share one.
        var same = wait(5) { (try? self.checksum(library)) == developed }
        for _ in 0..<3 where !same {
            backToGrid(library)
            let again = cell("IMG_0001", library)
            XCTAssert(again.waitForExistence(timeout: 5), "the grid has no IMG_0001 after the loupe")
            again.doubleClick()
            same = wait(5) { (try? self.checksum(library)) == developed }
        }
        XCTAssert(same, "the picture changed across the relaunch")
        backToGrid(library)
        let first = cell("IMG_0001", library)
        XCTAssert(first.waitForExistence(timeout: 5), "the grid has no IMG_0001 after the loupe")
        XCTAssert(wait(2) { Self.text(first).hasPrefix("ready") }, "IMG_0001's cell reads \(Self.text(first))")
        library.app.terminate()
    }

    /// Step 11 (F): a failed render says so under the histogram.
    @MainActor private func errorState() throws {
        // The bare -LibraryTestValues switch goes last, or it takes -LibraryFakeMode as its value (Journey.init).
        let library = Journey(
            "Library", self, arguments: ["-LibraryFixture", "shoot", "-LibraryFakeMode", "fail", "-LibraryTestValues"])
        sortByName(library)
        cell("IMG_0001", library).doubleClick()
        developTab(library)
        let error = library.element("library.develop.error")
        XCTAssert(error.waitForExistence(timeout: 5), "no render error (library.develop.error)")
        library.shot("develop-error")
        XCTAssertEqual(Self.text(error), "Couldn't render this photo: the preview failed on purpose.")
        library.app.terminate()
    }

    /// The (L) pass: steps 1 to 10 on real files imported on launch.
    @MainActor private func livePass() throws {
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        let shoot = try LibraryFiles.writeShoot(in: folder)
        let arguments = ["-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
                         "-LibraryImportOnLaunch", "-LibraryTestValues"]
        try openDevelop(arguments, suffix: "-live", imports: shoot.count)
        try dragExposure(suffix: "-live")
        try stepContrast()
        try undoContrast()
        try showOriginal(suffix: "-live")
        try editCurveAndLevels(suffix: "-live")
        try copyAndPaste(suffix: "-live")
        try sync(suffix: "-live")
        try reset()
        try relaunch(arguments, catalog: catalog)
    }

    // MARK: - Helpers

    /// Clicks the inspector's Develop tab (a new window opens on Info).
    @MainActor private func developTab(_ library: Journey) {
        let tab = library.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == 'Develop'")).firstMatch
        XCTAssert(tab.waitForExistence(timeout: 5), "the inspector has no Develop tab")
        tab.click()
    }

    /// The loupe render's quality, the first word of the loupe value probe's label ("full", "preview").
    @MainActor private func loupeQuality(_ library: Journey) -> String {
        library.element("library.loupe.value").label.split(separator: " ").first.map(String.init) ?? ""
    }

    /// The Exposure `catalog.json` in `catalog` holds for the photo named `name`; 0 when its develop is
    /// left out (neutral), nil while the file or the photo is missing: the `library.catalog` stand-in.
    private static func savedExposure(in catalog: URL, of name: String) -> Double? {
        guard let data = try? Data(contentsOf: catalog.appending(path: "catalog.json")),
            let top = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let photos = top["photos"] as? [[String: Any]],
            let photo = photos.first(where: { $0["name"] as? String == name })
        else { return nil }
        guard let develop = photo["develop"] as? [String: Any] else { return 0 }
        return (develop["exposure"] as? NSNumber)?.doubleValue
    }

    /// The checksum of the loupe's full render once it has held still for half a second.
    @MainActor private func settledChecksum(_ library: Journey) throws -> String {
        var last = "", since = Date()
        let settled = wait(10) {
            let now = loupeQuality(library) == "full" ? ((try? checksum(library)) ?? "") : ""
            if now != last { (last, since) = (now, Date()) }
            return !now.isEmpty && Date().timeIntervalSince(since) >= 0.5
        }
        XCTAssert(settled, "the loupe's full render never held still")
        return try checksum(library)
    }

    /// Polls `condition` every tenth of a second for up to `seconds`.
    @MainActor private func wait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return condition()
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func cell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }

    /// Leaves the loupe by its Grid button. Escape goes only to a focused loupe, and the
    /// Develop tab's click has just taken the focus.
    @MainActor private func backToGrid(_ library: Journey) {
        let grid = library.element("library.loupe.grid")
        XCTAssert(grid.waitForExistence(timeout: 3), "the loupe has no Grid button (library.loupe.grid)")
        grid.click()
    }

    /// The Develop row of `slider` ("Exposure"): `library.develop.exposure`.
    @MainActor private func row(_ slider: String, _ library: Journey) -> XCUIElement {
        library.element("library.develop.\(slider.lowercased())")
    }

    /// Scrolls the Develop list until `element` lies whole inside it. XCUITest scrolls
    /// to click a row, but it right-clicks or drags a control hidden outside the list
    /// at its frame, which is another control's place (#3560).
    @MainActor private func scrollDevelop(toShow element: XCUIElement, _ library: Journey) {
        let list = library.element("suite.inspector").scrollViews.firstMatch
        XCTAssert(element.waitForExistence(timeout: 5), "nothing to scroll to in the Develop list")
        for _ in 0..<20 where !list.frame.contains(element.frame) {
            list.scroll(byDeltaX: 0, deltaY: element.frame.minY < list.frame.minY ? 40 : -40)
        }
        XCTAssert(list.frame.contains(element.frame), "\(element.frame) didn't scroll into \(list.frame)")
    }

    /// The first element in the inspector whose label is `label`.
    @MainActor private func inspectorItem(_ label: String, _ library: Journey) -> XCUIElement {
        library.element("suite.inspector").descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Waits for the window and IMG_0024's cell, then View > Sort By > Name.
    @MainActor private func sortByName(_ library: Journey) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(cell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        let byName = sort.menuItems["Name"]
        XCTAssert(byName.waitForExistence(timeout: 3), "View > Sort By has no Name")
        byName.click()
    }

    /// Edit's first item reads `title` ("Undo Exposure").
    @MainActor private func expectUndo(_ title: String, _ library: Journey) {
        let edit = library.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let undo = edit.menuItems.matching(NSPredicate(format: "title BEGINSWITH 'Undo'")).firstMatch
        XCTAssert(undo.waitForExistence(timeout: 3), "the Edit menu has no Undo")
        XCTAssertEqual(undo.title, title, "Edit's Undo")
        library.press(.escape)
    }

    /// The loupe render's checksum: the 16 hex digits in the loupe value probe's label.
    @MainActor private func checksum(_ library: Journey) throws -> String {
        let value = library.element("library.loupe.value").label
        let words = value.split(separator: " ").map(String.init)
        return try XCTUnwrap(words.first { $0.count == 16 && $0.allSatisfy(\.isHexDigit) },
                             "the loupe photo's value \"\(value)\" has no checksum")
    }

    /// What an element reads: a slider row's number (macOS gives a slider's value as an NSNumber), else its
    /// string value, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        if let number = element.value as? NSNumber { return number.stringValue }
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// The first number an element reads ("+0.50 EV" is 0.5); nil reads as NaN.
    @MainActor private static func number(_ element: XCUIElement) -> Double {
        let words = text(element).split(whereSeparator: { !"+-.0123456789".contains($0) })
        return words.lazy.compactMap { Double($0) }.first ?? .nan
    }

    /// The histogram readout's mean ("mean 0.42 …").
    @MainActor private static func mean(_ histogram: XCUIElement) -> Double {
        let words = text(histogram).split(separator: " ")
        guard let at = words.firstIndex(of: "mean"), words.index(after: at) < words.endIndex else { return .nan }
        return Double(words[words.index(after: at)]) ?? .nan
    }
}
