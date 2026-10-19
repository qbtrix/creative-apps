// DesignJourneyTests+Layers.swift: the Layers steps Design's journeys share.
// A document opens with every layer row collapsed (DesignWorkspace.load clears
// the expanded rows), so on `cards` only Desktop's row shows until its
// disclosure opens; a journey that clicks A, Title or Hidden opens Desktop
// first (#2456, #2457). The disclosure is the triangle in the parent's
// outline row, found by the row's `design.layer.<id>`; clicking it changes
// no selection. A row is clicked in its blank space, between the name and the
// Hide toggle: a click on the name itself doesn't select the row (#2496).
// DesignLayersJourneyTests holds the Layers panel's own journeys: a group
// row's eye hides the group (L-6, #2758). A group's row reads as one checkbox
// (#2410), so its eye is clicked at the toggle column a child row's own eye
// shows: a toggle sits at the same x in every row (#53).
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

    /// Clicks the Layers row `identifier` midway between its name and its Hide toggle (#2496),
    /// holding `modifiers`; a row with no name or toggle in reach is clicked at 60% of its width.
    func clickDesignLayer(_ identifier: String, modifiers: XCUIElement.KeyModifierFlags = []) {
        let layer = element("suite.sidebar").descendants(matching: .any)[identifier].firstMatch
        XCTAssert(layer.waitForExistence(timeout: 5), "no \(identifier) row in Layers")
        let row = layer.frame, title = layer.staticTexts.firstMatch, toggle = layer.checkBoxes.firstMatch
        var dx = 0.6
        if row.width > 0, title.exists, toggle.exists, title.frame.maxX < toggle.frame.minX {
            dx = Double((title.frame.maxX + toggle.frame.minX) / 2 - row.minX) / Double(row.width)
        }
        let point = layer.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5))
        XCUIElement.perform(withKeyModifiers: modifiers) { point.click() }
    }

    /// The first element inside `row` whose label is `label`.
    func designLayerToggle(_ row: XCUIElement, _ label: String) -> XCUIElement {
        row.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}

/// The Layers panel's journeys (layers-panel). J12, `testLayersRenameReorderNest`, is L-5's.
final class DesignLayersJourneyTests: XCTestCase {
    /// `cards`' Desktop frame (node-1), the group Pair (node-6) in it, and Pair's ellipses E1 and E2.
    static let desktopRow = "design.layer.node-1", pairRow = "design.layer.node-6"
    static let childRows = ["design.layer.node-7", "design.layer.node-8"]

    /// L-6 (#2758, #589): an open group's row has an eye. A click hides the group as one
    /// "Hide Layer" step; its children read hidden by it and stay listed; ⌘Z shows it again.
    @MainActor func testGroupRowEyeHidesGroup() {
        let design = Journey("Design", self, arguments: ["-DesignFixture", "cards"])
        XCTAssert(design.element(Self.desktopRow).waitForExistence(timeout: 30), "cards showed no Desktop row")
        design.expandDesignLayer(Self.desktopRow)
        design.expandDesignLayer(Self.pairRow)
        for child in Self.childRows {
            XCTAssert(design.element(child).waitForExistence(timeout: 5), "opening Pair showed no \(child) row")
        }
        // Pair's row is one checkbox (#2410): its eye is at the x of E1's own eye, on Pair's row.
        let pair = design.element(Self.pairRow), e1 = design.element(Self.childRows[0])
        let childEye = design.designLayerToggle(e1, "Hide Layer")
        XCTAssert(childEye.waitForExistence(timeout: 5), "E1's row has no Hide Layer eye")
        design.shot("layers-group-open")
        let eyeOffset = CGVector(dx: childEye.frame.midX - pair.frame.minX, dy: pair.frame.height / 2)
        pair.coordinate(withNormalizedOffset: .zero).withOffset(eyeOffset).click()
        XCTAssert(design.app.buttons["Undo Hide Layer"].waitForExistence(timeout: 5), "Pair's eye made no undo step")
        for child in Self.childRows {
            let row = design.element(child)
            XCTAssert(row.exists, "hiding Pair collapsed it: no \(child) row")
            XCTAssert(design.designLayerToggle(row, "Hide Layer (its group is hidden)").waitForExistence(timeout: 5),
                      "\(child) doesn't show Pair's hidden state")
        }
        design.shot("layers-group-hidden")
        design.press(character: "z", .command)
        XCTAssert(e1.exists, "⌘Z collapsed Pair")
        XCTAssert(design.designLayerToggle(e1, "Hide Layer").waitForExistence(timeout: 5),
                  "⌘Z left Pair hidden: E1 still reads its group hidden")
        design.shot("layers-group-shown")
    }
}
