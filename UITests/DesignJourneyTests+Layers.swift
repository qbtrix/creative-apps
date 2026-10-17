// DesignJourneyTests+Layers.swift: the Layers steps Design's journeys share.
// A document opens with every layer row collapsed (DesignWorkspace.load clears
// the expanded rows), so on `cards` only Desktop's row shows until its
// disclosure opens; a journey that clicks A, Title or Hidden opens Desktop
// first (#2456, #2457). The disclosure is the triangle in the parent's
// outline row, found by the row's `design.layer.<id>`; clicking it changes
// no selection.
import XCTest

extension Journey {
    /// Opens the Layers row `identifier` (a frame or group) when it is collapsed, so its children's rows show.
    func expandDesignLayer(_ identifier: String) {
        let row = element("suite.sidebar").outlineRows.containing(.any, identifier: identifier).firstMatch
        XCTAssert(row.waitForExistence(timeout: 5), "no \(identifier) row in Layers")
        let triangle = row.disclosureTriangles.firstMatch
        XCTAssert(triangle.waitForExistence(timeout: 5), "the Layers row \(identifier) has no disclosure triangle")
        guard (triangle.value as? Int) != 1 else { return }
        triangle.click()
        let opened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 1"), object: triangle)
        XCTAssertEqual(XCTWaiter.wait(for: [opened], timeout: 5), .completed, "clicking \(identifier)'s disclosure didn't open it")
    }
}
