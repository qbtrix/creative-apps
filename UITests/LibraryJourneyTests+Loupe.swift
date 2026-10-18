// LibraryJourneyTests+Loupe.swift: J3, the loupe shows the photo's real
// pixels, zooms, pans and steps (packet
// docs/blueprints/library/features/loupe-viewport.md, Journey steps). Steps 1
// to 5 run on the `shoot` fixture's fakes; then step 1's loading sub-step
// relaunches with `-LibraryFakeMode slow`, where the grid thumbnail shows at
// once as a `preview` and the `full` render lands 2 s later. LV-10 runs
// steps 1 to 5 again live, on the 24 JPEGs `LibraryFiles.writeShoot`
// writes, imported on launch (`-LibraryImportOnLaunch`; those shots end
// `-live`): each written file reaches `full` within 2 s. The loupe photo
// (`library.loupe.photo`) carries `loupeValue` as its value ("full 2048×1365
// 100% No stars"); the readout (`library.loupe.position`) reads "<name>  ·
// <n> of 24  ·  <cull summary>". Grid cells are `library.grid.cell.<photo id>`
// with "ready W×H …" as their value once their thumbnail is in. In the loupe
// Escape goes back to the grid, so the journey clicks the loupe before keys
// that must reach it after a menu. The step 1 shot is `loupe-open`: the older
// `testLoupeStepsAndReturnsToTheGrid` already shoots `loupe`, and each shot
// name is unique within the app.
import AppKit
import XCTest

extension LibraryJourneyTests {
    /// J3: open a photo in the loupe at its real size, step, zoom to 100%,
    /// pan, Zoom to Fit, End and Home, and return to the grid on the photo.
    @MainActor func testLoupeStepsZoomsAndReturns() throws {
        loupeSteps(Journey("Library", self, arguments: ["-LibraryFixture", "shoot"]), suffix: "")

        // Step 1 (F), loading: the held thumbnail shows at once as `preview`,
        // the slow fake render replaces it with `full`.
        let slow = Journey("Library", self, arguments: ["-LibraryFixture", "shoot", "-LibraryFakeMode", "slow"])
        loupeSortByName(slow)
        let cell = loupeCell("IMG_0001", slow)
        XCTAssert(cell.waitForExistence(timeout: 10), "no grid cell for IMG_0001")
        XCTAssert(
            loupeWait(20) { ((cell.value as? String) ?? "").hasPrefix("ready") },
            "IMG_0001's thumbnail never came in: \(cell.value as? String ?? "")")
        cell.doubleClick()
        expectLoupeValue(prefix: "preview", within: 1.5, slow)
        slow.shot("loupe-preview")
        expectLoupeValue(prefix: "full", within: 6, slow)
        slow.app.terminate()

        // Live (LV-10): the same steps on real files imported on launch.
        let folder = try LibraryFiles.freshPhotoFolder()
        let catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        try LibraryFiles.writeShoot(in: folder)
        loupeSteps(Journey("Library", self, arguments: [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path, "-LibraryImportOnLaunch",
        ]), suffix: "-live")
    }

    /// J3 steps 1 to 5 on `library`, each shot's name ending `suffix`.
    @MainActor private func loupeSteps(_ library: Journey, suffix: String) {
        // Step 1: by name, double-click the first cell: IMG_0001, `full` within 2 s.
        loupeSortByName(library)
        let first = loupeCell("IMG_0001", library)
        XCTAssert(first.waitForExistence(timeout: 10), "no grid cell for IMG_0001")
        first.doubleClick()
        XCTAssert(library.element("library.loupe").waitForExistence(timeout: 10), "double-click didn't open the loupe")
        expectLoupeValue(prefix: "full", within: 2, library)
        expectLoupePosition("IMG_0001", "1 of 24", library)
        library.shot("loupe-open\(suffix)")

        // Step 2: Right twice steps to the third photo.
        focusLoupePhoto(library)
        library.press(.rightArrow)
        library.press(.rightArrow)
        expectLoupePosition("IMG_0003", "3 of 24", library)
        library.shot("loupe-step\(suffix)")

        // Step 3: View > Actual Size draws the photo at 100%.
        chooseLoupeViewItem("Actual Size", library)
        let photo = library.element("library.loupe.photo")
        XCTAssert(
            loupeWait(5) { ((photo.value as? String) ?? "").contains("100%") },
            "after Actual Size the loupe photo reads \(photo.value as? String ?? "")")
        library.shot("loupe-100\(suffix)")

        // Step 4: scroll the photo 200 pt left. Which way a wheel delta goes is
        // the runner's setting, so when the first scroll moved it right, scroll
        // back past the start; the scroll's unit is the display's pixel, so at
        // 2x the photo may move 100 pt.
        let area = library.element("library.loupe").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let start = photo.frame.minX
        area.scroll(byDeltaX: -200, deltaY: 0)
        _ = loupeWait(2) { photo.frame.minX != start }
        if photo.frame.minX >= start {
            area.scroll(byDeltaX: photo.frame.minX > start ? 400 : 200, deltaY: 0)
            _ = loupeWait(2) { photo.frame.minX < start }
        }
        library.shot("loupe-pan\(suffix)")
        let moved = start - photo.frame.minX
        let scale = NSScreen.main?.backingScaleFactor ?? 1
        XCTAssert(
            abs(moved - 200) <= 2 || abs(moved - 200 / scale) <= 2,
            "scrolling 200 left moved the photo \(moved) pt left (from x \(start))")

        // Step 5: Zoom to Fit; End and Home; Right twice; Escape to the grid on IMG_0003.
        chooseLoupeViewItem("Zoom to Fit", library)
        focusLoupePhoto(library)
        library.press(.end)
        expectLoupePosition("IMG_0024", "24 of 24", library)
        library.press(.home)
        expectLoupePosition("IMG_0001", "1 of 24", library)
        library.press(.rightArrow)
        library.press(.rightArrow)
        expectLoupePosition("IMG_0003", "3 of 24", library)
        library.press(.escape)
        XCTAssert(library.element("library.loupe").waitForNonExistence(timeout: 5), "Escape left it in the loupe")
        let third = loupeCell("IMG_0003", library)
        XCTAssert(third.waitForExistence(timeout: 5), "no grid cell for IMG_0003 after Escape")
        XCTAssert(loupeWait(3) { third.isSelected }, "the grid came back without IMG_0003 selected")
        library.shot("loupe-grid\(suffix)")
        library.app.terminate()
    }

    // MARK: - Loupe helpers

    /// Polls `condition` every tenth of a second for up to `seconds`.
    @MainActor private func loupeWait(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: seconds)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        } while Date() < deadline
        return condition()
    }

    /// The grid cell `library.grid.cell.<id>` whose photo id names `name`.
    @MainActor private func loupeCell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }

    /// Waits for the window and IMG_0024's cell, then View > Sort By > Name.
    /// IMG_0024 leads in capture order; a live import scans every file before
    /// it adds the first, so the rest follow it within a batch or two.
    @MainActor private func loupeSortByName(_ library: Journey) {
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(loupeCell("IMG_0024", library).waitForExistence(timeout: 60), "no grid cell for IMG_0024")
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let sort = view.menuItems["Sort By"]
        XCTAssert(sort.waitForExistence(timeout: 3), "the View menu has no Sort By")
        sort.hover()
        let byName = sort.menuItems["Name"]
        XCTAssert(byName.waitForExistence(timeout: 3), "View > Sort By has no Name")
        byName.click()
    }

    /// Opens View and chooses its enabled item `title`.
    @MainActor private func chooseLoupeViewItem(_ title: String, _ library: Journey) {
        let view = library.app.menuBars.firstMatch.menuBarItems["View"]
        view.click()
        let item = view.menuItems[title]
        XCTAssert(item.waitForExistence(timeout: 3), "the View menu has no \(title)")
        XCTAssert(item.isEnabled, "View > \(title) is disabled in the loupe")
        item.click()
    }

    /// Clicks the loupe photo (or the loupe when it isn't drawn) so its keys reach it after a menu.
    @MainActor private func focusLoupePhoto(_ library: Journey) {
        let photo = library.element("library.loupe.photo")
        if photo.waitForExistence(timeout: 3), photo.isHittable {
            photo.click()
        } else {
            library.element("library.loupe").click()
        }
    }

    /// Within `seconds` the loupe photo's value starts `prefix`.
    @MainActor private func expectLoupeValue(prefix: String, within seconds: TimeInterval, _ library: Journey) {
        let photo = library.element("library.loupe.photo")
        XCTAssert(
            loupeWait(seconds) { ((photo.value as? String) ?? "").hasPrefix(prefix) },
            "within \(seconds) s the loupe photo reads \"\(photo.value as? String ?? "")\", not \(prefix)…")
    }

    /// Within five seconds the readout names `name` and has a part that is
    /// exactly `position`, so "1 of 24" never matches "11 of 24".
    @MainActor private func expectLoupePosition(_ name: String, _ position: String, _ library: Journey) {
        let readout = library.element("library.loupe.position")
        var text = ""
        let found = loupeWait(5) {
            let value = (readout.value as? String) ?? ""
            text = value.isEmpty ? readout.label : value
            let parts = text.split(separator: "·").map { $0.trimmingCharacters(in: .whitespaces) }
            return text.contains(name) && parts.contains(position)
        }
        XCTAssert(found, "the loupe reads \"\(text)\", not \(name) at \(position)")
    }
}
