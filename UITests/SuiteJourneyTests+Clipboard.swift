// SuiteJourneyTests+Clipboard.swift: SJ-CB (clipboard-interop CB-u2, packet
// docs/blueprints/suiteui/features/clipboard-interop.md, Journey steps). On the
// gallery's `menu-command` page it opens Edit > Copy As and finds its three
// items, PNG, SVG and the page's own type ("Gallery Layers"), built by
// CopyAsMenu from CopyAsCommands. It clicks Copy Text, which puts text on the
// page's fake pasteboard, and opens Edit again: Paste as Image is off, and the
// page's help line (`suite.gallery.menu-command.paste-help`, the item's help)
// says why in the coder's sentence. Copy As > PNG then turns it on.
import XCTest

final class SuiteClipboardJourneyTests: XCTestCase {
    /// The Copy As items, in menu order.
    private static let copyAsItems = ["PNG", "SVG", "Gallery Layers"]

    /// SJ-CB: Edit > Copy As lists three items; with text on the pasteboard Paste as Image is off and says why.
    @MainActor func testCopyAsMenuInGallery() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "menu-command"])
        XCTAssert(gallery.element("suite.gallery.menu-command").waitForExistence(timeout: 30), "no menu-command page")
        let edit = gallery.element("suite.gallery.menu-command.menu")
        XCTAssert(edit.waitForExistence(timeout: 10), "no Edit menu (suite.gallery.menu-command.menu)")

        // 1. Open Edit > Copy As: three items in order.
        edit.click()
        let copyAs = gallery.app.menuItems["Copy As"].firstMatch
        XCTAssert(copyAs.waitForExistence(timeout: 5), "Edit has no Copy As")
        copyAs.hover()
        var lastY = -CGFloat.infinity
        for title in Self.copyAsItems {
            let item = copyAs.menuItems[title].firstMatch
            XCTAssert(item.waitForExistence(timeout: 5), "Copy As has no \(title)")
            XCTAssert(item.isEnabled, "Copy As > \(title) is off with a selection")
            XCTAssert(item.frame.minY > lastY, "Copy As > \(title) is out of order")
            lastY = item.frame.minY
        }
        gallery.shot("copy-as", screen: true)
        gallery.press(.escape)
        gallery.press(.escape)
        XCTAssert(clipboardWait { !copyAs.exists }, "the Edit menu stayed open after Escape")

        // 2. Put text on the fake pasteboard: Paste as Image is off and its help is the coder's sentence.
        gallery.element("suite.gallery.menu-command.copy-text").click()
        let pasteboard = gallery.element("suite.gallery.menu-command.pasteboard")
        XCTAssert(clipboardWait { (pasteboard.value as? String ?? "") == "Pasteboard: text" },
                  "the pasteboard line reads \(pasteboard.value ?? "nothing"), not Pasteboard: text")
        let help = gallery.element("suite.gallery.menu-command.paste-help")
        let why = help.value as? String ?? ""
        XCTAssert(why.hasPrefix("Paste as Image: ") && why.count > "Paste as Image: ".count,
                  "Paste as Image's help reads \(why), not its why-not")
        edit.click()
        let paste = gallery.app.menuItems["Paste as Image"].firstMatch
        XCTAssert(paste.waitForExistence(timeout: 5), "Edit has no Paste as Image")
        XCTAssertFalse(paste.isEnabled, "Paste as Image is on with text on the pasteboard")
        gallery.shot("copy-as-paste-off", screen: true)

        // 3. Copy As > PNG: the pasteboard holds a PNG and Paste as Image is on.
        gallery.app.menuItems["Copy As"].firstMatch.hover()
        gallery.app.menuItems["Copy As"].firstMatch.menuItems["PNG"].firstMatch.click()
        XCTAssert(clipboardWait { (pasteboard.value as? String ?? "") == "Pasteboard: public.png" },
                  "after Copy As > PNG the pasteboard line reads \(pasteboard.value ?? "nothing")")
        edit.click()
        XCTAssert(clipboardWait { gallery.app.menuItems["Paste as Image"].firstMatch.isEnabled },
                  "Paste as Image stayed off with a PNG on the pasteboard")
        gallery.press(.escape)
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func clipboardWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
