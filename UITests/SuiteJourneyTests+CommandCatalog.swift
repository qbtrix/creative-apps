// SuiteJourneyTests+CommandCatalog.swift: the gallery's `command-catalog` page
// (packet docs/blueprints/suiteui/features/command-catalog.md, Journey step 4;
// CC-9, turned on by CC-10). From the index it clicks the page's row and finds
// the six rows of the fake catalog, each a MenuCommand built from its spec
// (`suite.gallery.command-catalog.<id>`). On the empty document "Remove
// Rectangle" is disabled and its help line reads "Select a rectangle first.".
// Clicking "Add Rectangle" runs the spec on the page's document: the document
// line reads "1 rect" and the Edit row (`suite.gallery.status`) reads
// "Undo Add Rectangle".
import XCTest

extension SuiteJourneyTests {
    /// The page's rows: the fake catalog's six commands, in menu order.
    private static let catalogRows = ["rect.add", "rect.move", "rect.remove", "rect.select", "rect.list", "doc.export-json"]

    /// CC-9: the command-catalog page lists the fake's commands, says why Remove can't run, and runs Add.
    @MainActor func testCommandCatalogGallery() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")

        // 1. Open the page from the index: six rows, Remove disabled with its why-not as help.
        gallery.element("suite.gallery.index.command-catalog").click()
        XCTAssert(gallery.element("suite.gallery.command-catalog").waitForExistence(timeout: 10),
                  "no root suite.gallery.command-catalog")
        for id in Self.catalogRows {
            XCTAssert(gallery.element("suite.gallery.command-catalog.\(id)").waitForExistence(timeout: 5),
                      "no row for \(id) (suite.gallery.command-catalog.\(id))")
        }
        let remove = gallery.element("suite.gallery.command-catalog.rect.remove")
        XCTAssertFalse(remove.isEnabled, "Remove Rectangle is enabled on an empty document")
        let help = gallery.element("suite.gallery.command-catalog.rect.remove.help")
        XCTAssert((help.value as? String ?? "").contains("Select a rectangle first."),
                  "Remove's help reads \(help.value ?? "nothing"), not its why-not")
        gallery.shot("command-catalog")

        // 2. Click Add Rectangle: the document holds one rect and the Edit row names the step.
        gallery.element("suite.gallery.command-catalog.rect.add").click()
        let document = gallery.element("suite.gallery.command-catalog.document")
        let one = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1 rect"), object: document)
        XCTAssertEqual(XCTWaiter().wait(for: [one], timeout: 5), .completed,
                       "after Add Rectangle the document reads \(document.value ?? "nothing")")
        let status = gallery.element("suite.gallery.status")
        let named = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Undo Add Rectangle"), object: status)
        XCTAssertEqual(XCTWaiter().wait(for: [named], timeout: 5), .completed,
                       "the Edit row reads \(status.value ?? "nothing"), not Undo Add Rectangle")
        XCTAssert(gallery.element("suite.gallery.command-catalog.edit.undo").isEnabled, "Undo is disabled after an edit")
        gallery.shot("command-catalog-ran")
    }
}
