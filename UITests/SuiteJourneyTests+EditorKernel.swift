// SuiteJourneyTests+EditorKernel.swift: EK-4, the gallery's `editor-kernel`
// page (packet docs/blueprints/suiteui/features/editor-kernel.md, Journey
// steps 1 and 2). From the index it clicks the page's row, finds LayerTreeList
// (`suite.layers`) with Card 7's row (`suite.layers.row.card-7`), shoots it,
// then drags Card 7 onto Header's row with the mouse: the page's log
// (`suite.gallery.log`) reads `move(into: "header", at: 3)`. Written before
// its code (lead.md, contract rule 13): EK-6 turns it on, and the row landing
// as Header's last child needs EK-12's `LayerTree.move` body.
import XCTest

extension SuiteJourneyTests {
    /// EK-4: the editor-kernel page lists the tree and proposes a drop into Header.
    @MainActor func testEditorKernelGallery() throws {
        throw XCTSkip("waits on EK-6")
        try walkEditorKernel()
    }

    /// The journey itself, which EK-6 runs once it drops the skip above.
    @MainActor private func walkEditorKernel() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")

        // 1. Open the page from the index: the list shows Card 7's row.
        gallery.element("suite.gallery.index.editor-kernel").click()
        XCTAssert(gallery.element("suite.gallery.editor-kernel").waitForExistence(timeout: 10),
                  "no root suite.gallery.editor-kernel")
        XCTAssert(gallery.element("suite.layers").waitForExistence(timeout: 5), "no LayerTreeList (suite.layers)")
        let card = gallery.element("suite.layers.row.card-7")
        XCTAssert(card.waitForExistence(timeout: 5), "no row for Card 7 (suite.layers.row.card-7)")
        gallery.shot("editor-kernel-tree")

        // 2. Drag Card 7 onto Header: the list proposes it as Header's last child.
        let header = gallery.element("suite.layers.row.header")
        XCTAssert(header.waitForExistence(timeout: 5), "no row for Header (suite.layers.row.header)")
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: header.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)))
        let log = gallery.element("suite.gallery.log")
        let moved = NSPredicate(format: "value CONTAINS %@", "move(into: \"header\", at: 3)")
        let wait = XCTNSPredicateExpectation(predicate: moved, object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed,
                       "the drop onto Header logged no move(into: \"header\", at: 3)")
        gallery.shot("editor-kernel-dropped")
    }
}
