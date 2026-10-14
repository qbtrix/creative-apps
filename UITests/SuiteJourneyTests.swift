// SuiteJourneyTests.swift: SuiteUI's own journeys (blueprint suiteui 4.1).
// SuiteUI has no app, so each one launches Library with `-SuiteGallery <page>`,
// which makes the window's whole body the component gallery, and shoots and
// audits under `suiteui` (`Journey(name:)`), so gallery shots never count under
// `library`. Each feature adds its own `SuiteJourneyTests+<Area>.swift`; the
// Journey template in project.yml compiles them all into this bundle, with
// SuiteControlInventory so a journey can judge `suite.controls` by the live rules.
import XCTest

final class SuiteJourneyTests: XCTestCase {
    /// SJ0: the index opens every page; each page's root is there, and its
    /// `suite.controls` lists every `suite.gallery.*` control on screen with
    /// no dead control or duplicate id. An unknown page names itself.
    @MainActor func testGalleryOpensEveryPage() {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index", "-SuitePerfProbe"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.shot("index-open")
        let rowPrefix = "suite.gallery.index."
        let index = expectControlsListed(gallery, page: "index")
        let rows = (index?.controls ?? []).map(\.id).filter { $0.hasPrefix(rowPrefix) }
        XCTAssertFalse(rows.isEmpty, "the index lists no pages")
        for row in rows {
            let page = String(row.dropFirst(rowPrefix.count))
            gallery.element(row).click()
            XCTAssert(gallery.element("suite.gallery.\(page)").waitForExistence(timeout: 10), "no root suite.gallery.\(page)")
            gallery.shot("\(page)-open")
            expectControlsListed(gallery, page: page)
            gallery.element("suite.gallery.back").click()
            XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 10), "\(page) didn't go back to the index")
        }
        gallery.app.terminate()

        let unknown = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "nosuch"])
        let message = unknown.app.staticTexts["No gallery page named nosuch."]
        XCTAssert(message.waitForExistence(timeout: 30), "no empty state naming the unknown page")
        XCTAssert(unknown.element("suite.gallery.unknown").exists, "the unknown page has no suite.gallery.unknown root")
        unknown.shot("nosuch-unknown")
    }

    /// Every control on screen with a `suite.gallery.` identifier is in
    /// `suite.controls`, and a SuiteControlInventory rebuilt from the
    /// document has no violations. Registration follows the page's
    /// appearance, so the document gets two seconds to catch up. Returns it.
    @discardableResult
    @MainActor private func expectControlsListed(_ gallery: Journey, page: String) -> ControlDocument? {
        var missing: [String] = []
        var document: ControlDocument?
        for _ in 0..<10 {
            document = gallery.controls()
            let listed = Set(document?.controls.map(\.id) ?? [])
            missing = galleryControls(gallery).filter { !listed.contains($0) }.sorted()
            // Every page lists at least its back button or, on the index, its rows.
            if missing.isEmpty, document?.controls.isEmpty == false { break }
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssert(missing.isEmpty, "\(page): on screen but not in suite.controls: \(missing)")
        var inventory = SuiteControlInventory()
        for entry in document?.controls ?? [] { inventory.register(entry) }
        XCTAssertEqual(inventory.violations(), [], "\(page): suite.controls has dead or duplicate controls")
        return document
    }

    /// The identifiers of the window's controls that start with `suite.gallery.`.
    @MainActor private func galleryControls(_ gallery: Journey) -> Set<String> {
        guard let tree = try? gallery.app.windows.firstMatch.snapshot() else {
            XCTFail("no window snapshot")
            return []
        }
        var found: Set<String> = []
        var pending: [any XCUIElementSnapshot] = [tree]
        while let node = pending.popLast() {
            if node.identifier.hasPrefix("suite.gallery."), Self.controlTypes.contains(node.elementType) {
                found.insert(node.identifier)
            }
            pending.append(contentsOf: node.children)
        }
        return found
    }

    /// The element types a person acts on; page roots and logs are not controls.
    private static let controlTypes: Set<XCUIElement.ElementType> = [
        .button, .toolbarButton, .checkBox, .radioButton, .switch, .toggle, .slider, .stepper, .popUpButton,
        .menuButton, .comboBox, .textField, .searchField, .segmentedControl, .colorWell, .link, .tab,
        .incrementArrow, .decrementArrow, .disclosureTriangle,
    ]
}
