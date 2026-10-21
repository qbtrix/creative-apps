// SuiteJourneyTests+AreaSelect.swift: SJ-AR, the gallery's `area-select` page (area-selection AR-8, the packet's
// Journey steps; docs/blueprints/suiteui/features/area-selection.md): open the page, drag a lasso, pick Subtract,
// set Feather to 4, click the wand; the ants follow (the canvas counts its outlines) and every option shows its
// state. The page runs each command on a local fake and logs a line per command in `suite.gallery.log`.
import XCTest

final class SuiteAreaSelectJourneyTests: XCTestCase {
    @MainActor func testAntsAndOptionsInGallery() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.area-select").click() // 1. Open the Area Select page.
        XCTAssert(gallery.element("suite.gallery.area-select").waitForExistence(timeout: 10), "no suite.gallery.area-select")
        let canvas = gallery.element("suite.gallery.area-canvas")
        XCTAssert(canvas.exists, "no suite.gallery.area-canvas")
        gallery.shot("area-select-open")

        gallery.element("suite.area.tool-lasso").click() // 2. Drag a lasso.
        XCTAssert(gallery.element("suite.area.tool-lasso").isSelected, "the Lasso chip isn't selected")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7)))
        expectAreaLog(gallery, "select.lasso replace")
        expectShapes(canvas, 1)
        gallery.shot("area-select-lasso")

        gallery.element("suite.area.mode-subtract").click() // 3. Pick Subtract.
        expectAreaLog(gallery, "select.lasso mode")
        XCTAssert(gallery.element("suite.area.mode-subtract").isSelected, "the Subtract chip isn't selected")

        let feather = gallery.element("suite.area.feather") // 4. Feather to 4.
        feather.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        gallery.app.typeText("4")
        gallery.press(.return)
        expectAreaLog(gallery, "select.feather")
        XCTAssert((feather.value as? String ?? "").hasPrefix("4"), "Feather reads \(feather.value ?? "nothing"), not 4")
        gallery.shot("area-select-feather")

        gallery.element("suite.area.tool-wand").click() // 5. Click the wand; its options show.
        for id in ["suite.area.tolerance", "suite.area.contiguous", "suite.area.all-layers"] {
            XCTAssert(gallery.element(id).waitForExistence(timeout: 5), "the wand shows no \(id)")
        }
        XCTAssert(gallery.element("suite.area.mode-subtract").isSelected, "the mode left Subtract with the wand")
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.45)).click()
        expectAreaLog(gallery, "select.wand subtract")
        expectShapes(canvas, 2)
        gallery.shot("area-select-wand")
    }

    /// Waits up to five seconds for the log's last line to start with `prefix` and not be refused.
    @MainActor private func expectAreaLog(_ gallery: Journey, _ prefix: String) {
        var last = ""
        for _ in 0..<10 {
            last = gallery.areaLog.components(separatedBy: "\n").last ?? ""
            if last.hasPrefix(prefix) && !last.contains("refused") { return }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("the log's last line is \(last), not \(prefix); it reads \(gallery.areaLog)")
    }

    /// Waits up to five seconds for the canvas to count `count` outlines under its ants.
    @MainActor private func expectShapes(_ canvas: XCUIElement, _ count: Int) {
        for _ in 0..<10 where (canvas.value as? String) != "\(count) shapes" { Thread.sleep(forTimeInterval: 0.5) }
        XCTAssertEqual(canvas.value as? String, "\(count) shapes", "the ants don't trace \(count) outlines")
    }
}

extension Journey {
    /// The area page's `suite.gallery.log` value; empty when the page has none.
    @MainActor fileprivate var areaLog: String { element("suite.gallery.log").value as? String ?? "" }
}
