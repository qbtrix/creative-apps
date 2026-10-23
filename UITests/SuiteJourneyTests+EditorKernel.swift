// SuiteJourneyTests+EditorKernel.swift: the gallery's `editor-kernel` page
// (packet docs/blueprints/suiteui/features/editor-kernel.md, Journey steps 1
// to 5; EK-4 and EK-5, turned on by EK-6). From the index it clicks the
// page's row and finds LayerTreeList (`suite.layers`). Rows run front to back
// and every container is open, so Header and Card 7 sit at the list's end: it
// scrolls there, shoots, and drags Card 7 (`suite.layers.row.card-7`) onto
// Header's row with the mouse. The page's log (`suite.gallery.log`) reads
// `move(into: "header", at: 3)` and Card 7's row now sits right under
// Header's, above Item 3: Header's last child, the frontmost. Beside the list,
// Card 1 to Card 4 are picked: the handles mark (`suite.handles`) shows eight
// handles and the rotate knob; hovering the top-left one names `.topLeft` in
// `suite.gallery.status`. The guides mark (`suite.guides`) reads its fake's
// `summary`. Steps 6 and 7 (Export, ToolKeys) belong to EK-chrome.
import XCTest

extension SuiteJourneyTests {
    /// The handles the mark draws: the eight resize handles and the rotate knob (`SelectionHandles.name`).
    private static let kernelHandles = ["topLeft", "top", "topRight", "right", "bottomRight", "bottom", "bottomLeft", "left", "rotate"]

    /// EK-4 and EK-5: the editor-kernel page lists the tree, drops Card 7 into Header, and marks the selection and guides.
    @MainActor func testEditorKernelGallery() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")

        // 1. Open the page from the index: the list shows; scroll to its end, where Card 7 and Header are.
        gallery.element("suite.gallery.index.editor-kernel").click()
        XCTAssert(gallery.element("suite.gallery.editor-kernel").waitForExistence(timeout: 10),
                  "no root suite.gallery.editor-kernel")
        let list = gallery.element("suite.layers")
        XCTAssert(list.waitForExistence(timeout: 5), "no LayerTreeList (suite.layers)")
        let card = gallery.element("suite.layers.row.card-7")
        let header = gallery.element("suite.layers.row.header")
        kernelScroll(list, until: ["header", "card-7"], in: gallery)
        gallery.shot("editor-kernel-tree")

        // 2. Drag Card 7 onto Header: it lands as Header's last child, the frontmost, so its row comes right
        // after Header's and before Item 3's.
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5))
            .press(forDuration: 0.3, thenDragTo: header.coordinate(withNormalizedOffset: CGVector(dx: 0.4, dy: 0.5)))
        let log = gallery.element("suite.gallery.log")
        let moved = NSPredicate(format: "value CONTAINS %@", "move(into: \"header\", at: 3)")
        let wait = XCTNSPredicateExpectation(predicate: moved, object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed,
                       "the drop onto Header logged no move(into: \"header\", at: 3)")
        let item = gallery.element("suite.layers.row.header-3")
        kernelScroll(list, until: ["header", "card-7", "header-3"], in: gallery)
        XCTAssert(header.frame.midY < card.frame.midY && card.frame.midY < item.frame.midY,
                  "Card 7's row isn't between Header's and Item 3's: \(header.frame), \(card.frame), \(item.frame)")
        gallery.shot("editor-kernel-dropped")

        // 3. Card 1 to Card 4 are picked: the mark shows eight handles and the rotate knob around their union.
        XCTAssert(gallery.element("suite.handles").waitForExistence(timeout: 5), "no handles mark (suite.handles)")
        for name in Self.kernelHandles {
            XCTAssert(gallery.element("suite.handles.\(name)").exists, "the mark has no \(name) handle (suite.handles.\(name))")
        }

        // 4. Hover the top-left handle: the status line names it.
        let status = gallery.element("suite.gallery.status")
        XCTAssert(status.waitForExistence(timeout: 5), "no status line (suite.gallery.status)")
        gallery.element("suite.handles.topLeft").hover()
        let named = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", ".topLeft"), object: status)
        XCTAssertEqual(XCTWaiter().wait(for: [named], timeout: 5), .completed,
                       "hovering the top-left handle didn't name .topLeft; the status reads \(status.value ?? "nothing")")
        gallery.shot("editor-kernel-handles")

        // 5. The guides fixture: a line at x 300 and the gaps of 100, read as the fake's summary.
        let guides = gallery.element("suite.guides")
        XCTAssert(guides.waitForExistence(timeout: 5), "no guides mark (suite.guides)")
        XCTAssertEqual(guides.value as? String, "x 300, gap x 100, spacing x 100", "the guides mark reads another summary")
    }

    /// Scrolls the middle of `list` toward its end until the row of every one of `ids` is hittable, at most 100 times.
    @MainActor private func kernelScroll(_ list: XCUIElement, until ids: [String], in gallery: Journey) {
        let rows = ids.map { gallery.element("suite.layers.row.\($0)") }
        let shown = { rows.allSatisfy { $0.exists && $0.isHittable } }
        var scrolls = 0
        while !shown(), scrolls < 100 {
            list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).scroll(byDeltaX: 0, deltaY: -300)
            scrolls += 1
        }
        XCTAssert(shown(), "\(scrolls) scrolls didn't show the rows of \(ids)")
    }
}
