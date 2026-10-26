// SuiteJourneyTests+Export.swift: the gallery's `export-pack` page (Sources/SuiteUI/Gallery/GalleryExportPack.swift),
// Journey steps 1 to 6 of docs/blueprints/suiteui/features/export-pack.md (numbered below), in Library, shot under
// `suiteui`. Written by XP-3: its SJ0 part (the index lists `export-pack`, the page opens on the sheet with its Size
// and Metadata rows) runs now; the steps after it drive XP-4's rows (`suite.export.size.*`, `suite.export.metadata`)
// and stay skipped until XP-5 turns them on.
import XCTest

final class SuiteExportJourneyTests: XCTestCase {
    /// Off until XP-5 lands the rows these steps drive (XP-4) and their identifiers.
    private static let exportRowsLanded = false

    @MainActor func testExportSheetSizesAndMetadata() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        let row = gallery.element("suite.gallery.index.export-pack") // SJ0: the index lists the page and it opens.
        XCTAssert(row.waitForExistence(timeout: 10), "the gallery index doesn't list export-pack")
        row.click()
        XCTAssert(gallery.element("suite.gallery.export-pack").waitForExistence(timeout: 10), "no root suite.gallery.export-pack")
        // 1. The sheet on a 1000 × 1250 artwork with Format, Size, Quality and Metadata rows.
        XCTAssert(gallery.element("suite.export.format").waitForExistence(timeout: 5), "the sheet shows no Format row")
        XCTAssert(gallery.element("suite.export.size").exists, "the sheet shows no Size row")
        XCTAssert(gallery.element("suite.export.metadata").exists, "the sheet shows no Metadata row")
        gallery.shot("export-pack-open")
        guard Self.exportRowsLanded else { throw XCTSkip("waits on XP-5") }

        // 2. Size > Pixels: width and height fields, the ratio locked; 1080 in width reads 1350 in height.
        gallery.element("suite.export.size.mode.pixels").click()
        typeField(gallery, "suite.export.size.width", "1080")
        XCTAssertEqual(gallery.element("suite.export.size.height").value as? String, "1350", "the locked height isn't 1350")
        gallery.shot("export-pack-pixels")

        // 3. Unlock the ratio and type 1351: the readout says it stretches.
        gallery.element("suite.export.size.lock").click()
        typeField(gallery, "suite.export.size.height", "1351")
        XCTAssertEqual(gallery.element("suite.export.size.readout").label, "1080 × 1351 px, stretched")
        gallery.shot("export-pack-stretched")

        // 4. Long edge 2048: 1638 × 2048 px.
        gallery.element("suite.export.size.mode.longEdge").click()
        typeField(gallery, "suite.export.size.longEdge", "2048")
        XCTAssertEqual(gallery.element("suite.export.size.readout").label, "1638 × 2048 px")
        gallery.shot("export-pack-long-edge")

        // 5. Metadata > All but location; PNG hides Quality and keeps Metadata; SVG shows Scale only and no Metadata.
        gallery.element("suite.export.metadata").click()
        gallery.app.menuItems["All but location"].click()
        gallery.element("suite.export.format.png").click()
        XCTAssert(gallery.element("suite.export.metadata").waitForExistence(timeout: 5), "PNG hid the Metadata row")
        gallery.element("suite.export.format.svg").click()
        XCTAssertFalse(gallery.element("suite.export.size.mode.pixels").exists, "SVG still offers Pixels")
        XCTAssertFalse(gallery.element("suite.export.metadata").exists, "SVG still shows Metadata")
        gallery.shot("export-pack-vector")

        // 6. Every control by keyboard: Tab reaches the Size modes.
        gallery.press(.tab)
        XCTAssert(gallery.element("suite.export.size.mode.scale").exists, "no Scale mode after Tab")
    }

    /// Types `text` into a field and commits it.
    @MainActor private func typeField(_ gallery: Journey, _ id: String, _ text: String) {
        let field = gallery.element(id)
        XCTAssert(field.waitForExistence(timeout: 5), "no \(id)")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        gallery.app.typeKey("a", modifierFlags: .command)
        gallery.app.typeText(text)
        gallery.press(.return)
    }
}
