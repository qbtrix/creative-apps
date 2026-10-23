// SuiteJourneyTests+Anchor.swift (anchor-parenting AN-6, journey SJ-AN): the
// gallery's `anchor` page on its fakes. Box 1 (120 × 80, anchor at its centre)
// and Box 2 (80 × 60) sit on the canvas with the anchor mark on Box 1's
// anchor and the anchor rows beside them. It drags the mark to Box 1's top
// left corner (the box stays put, the anchor reads 0, 0), picks Center in the
// nine-point picker (60, 40, still in place), parents Box 2 to Box 1 from the
// Parent menu (Box 2 stays put), then types -30 in the page's Rotation row for
// Box 1: Box 1 turns about its centre and Box 2 swings with it. The page's
// log (`suite.gallery.log`) names each command it ran.
import XCTest

final class SuiteAnchorJourneyTests: XCTestCase {
    /// A row's value as the rows read it out.
    @MainActor private static func value(_ gallery: Journey, _ id: String) -> String {
        let element = gallery.element(id)
        return (element.value as? String) ?? element.label
    }

    /// Whether two frames are the same to within a point.
    private static func same(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= 1 && abs(a.minY - b.minY) <= 1 && abs(a.width - b.width) <= 1 && abs(a.height - b.height) <= 1
    }

    /// Opens the menu button `id` and picks the item titled `title`.
    @MainActor private static func choose(_ gallery: Journey, _ id: String, _ title: String) {
        let menu = gallery.app.descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@ AND identifier == %@",
                        [XCUIElement.ElementType.menuButton, .popUpButton, .button].map(\.rawValue), id)).firstMatch
        XCTAssert(menu.waitForExistence(timeout: 5), "no menu \(id)")
        menu.click()
        let item = gallery.app.menuItems[title].firstMatch
        XCTAssert(item.waitForExistence(timeout: 5), "no \(title) in \(id)")
        item.click()
    }

    @MainActor func testDragAnchorAndParentInGallery() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")

        // Open the page: two boxes, the mark on Box 1's centre, its anchor at 60, 40.
        gallery.element("suite.gallery.index.anchor").click()
        XCTAssert(gallery.element("suite.gallery.anchor").waitForExistence(timeout: 10), "no root suite.gallery.anchor")
        let box1 = gallery.element("suite.gallery.anchor.box-1"), box2 = gallery.element("suite.gallery.anchor.box-2")
        let mark = gallery.element("suite.anchor.mark")
        XCTAssert(box1.exists && box2.exists && mark.exists, "no boxes or no anchor mark")
        let (one, two) = (box1.frame, box2.frame)
        XCTAssertEqual([Self.value(gallery, "suite.anchor.x"), Self.value(gallery, "suite.anchor.y")], ["60", "40"])
        gallery.shot("anchor-open")

        // 1. Drag the mark to Box 1's top left corner: one transform.set-anchor at 0, 0, and the box stays put.
        mark.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: box1.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)))
        XCTAssertEqual([Self.value(gallery, "suite.anchor.x"), Self.value(gallery, "suite.anchor.y")], ["0", "0"])
        XCTAssert(Self.same(box1.frame, one), "moving the anchor moved Box 1 from \(one) to \(box1.frame)")
        XCTAssert(abs(mark.frame.midX - one.minX) <= 2 && abs(mark.frame.midY - one.minY) <= 2, "the mark isn't on the corner")
        XCTAssert(gallery.element("suite.gallery.log").label.contains("transform.set-anchor"), "no transform.set-anchor in the log")
        gallery.shot("anchor-corner")

        // 2. Center in the nine-point picker: back to 60, 40, in place.
        gallery.element("suite.anchor.at-center").click()
        XCTAssertEqual([Self.value(gallery, "suite.anchor.x"), Self.value(gallery, "suite.anchor.y")], ["60", "40"])
        XCTAssert(Self.same(box1.frame, one), "Center moved Box 1")

        // 3. Choose Box 2 and parent it to Box 1: one layer.set-parent, and Box 2 stays put.
        Self.choose(gallery, "suite.gallery.anchor.layer", "Box 2")
        Self.choose(gallery, "suite.anchor.parent", "Box 1")
        XCTAssert(gallery.element("suite.gallery.log").label.contains("layer.set-parent"), "no layer.set-parent in the log")
        XCTAssert(Self.same(box2.frame, two), "parenting moved Box 2 from \(two) to \(box2.frame)")
        gallery.shot("anchor-parented")

        // 4. Choose Box 1 and turn it -30°: it turns about its centre, and Box 2 swings with it.
        Self.choose(gallery, "suite.gallery.anchor.layer", "Box 1")
        let rotation = gallery.element("suite.gallery.anchor.rotation")
        let bar = rotation.frame
        rotation.click()
        let fields = gallery.element("suite.gallery.anchor").textFields
        let typing = fields.allElementsBoundByIndex.first { $0.frame.midY >= bar.minY && $0.frame.midY <= bar.maxY }
            ?? fields.firstMatch
        XCTAssert(typing.waitForExistence(timeout: 5), "clicking the rotation row opened no field")
        gallery.press(character: "a", .command)
        typing.typeText("-30")
        gallery.press(.return)
        XCTAssert(abs(box1.frame.midX - one.midX) <= 1 && abs(box1.frame.midY - one.midY) <= 1, "Box 1 didn't turn about its centre")
        XCTAssertFalse(Self.same(box1.frame, one), "Box 1 didn't turn")
        // Box 2's centre, 160 right and 90 down of Box 1's, turned 30° counterclockwise about Box 1's
        // centre lands 184 right and 2 up of it: about 24 right and 92 up of where it was.
        let swing = CGVector(dx: box2.frame.midX - two.midX, dy: box2.frame.midY - two.midY)
        XCTAssert(abs(swing.dx - 23.6) <= 3 && abs(swing.dy + 92.1) <= 3, "Box 2 moved by \(swing), not with Box 1")
        gallery.shot("anchor-followed")
    }
}
