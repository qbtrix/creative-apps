// HaloJourneyTests+Edit.swift: HJ-CB (clipboard-interop CB-9 writes it skipped, CB-10 turns it on;
// packet docs/blueprints/suiteui/features/clipboard-interop.md, Journey steps). On `-HaloSample
// three-layers` (Intro, 1920 x 1080 at 24 fps, 72 frames; Title, Badge, Background, Rig) at 1000 x 640:
// the playhead scrubbed to frame 12 with Home and the right arrow, Edit > Copy Frame puts one
// 1920 x 1080 PNG on the general pasteboard (`edit-copy-frame`). A 160 x 100 PNG written to the
// pasteboard by the test, then Edit > Paste: one new layer row (comp-1-layer-5), "Undo Paste" first in
// the Edit menu, the playhead still at frame 12, where the layer starts (`edit-paste-image`).
import AppKit
import XCTest

final class HaloEditJourneyTests: XCTestCase {
    /// The slice this journey waits on; nil since CB-10 turned it on.
    private static let waitsOn: String? = nil
    static let arguments = ["-HaloSample", "three-layers", "-HaloWindowSize", "1000x640"]
    /// The row Halo gives the first layer added to Intro after its four.
    private static let pastedRow = "halo.layer.row.comp-1-layer-5"

    /// HJ-CB: Copy Frame writes the whole frame as a PNG; a PNG pasted in is one layer at the playhead.
    @MainActor func testCopyFramePasteImage() throws {
        if let waitsOn = Self.waitsOn { throw XCTSkip("waits on \(waitsOn)") }
        let halo = Journey("Halo", self, arguments: Self.arguments)
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(halo.element("halo.layer.row.comp-1-layer-4").waitForExistence(timeout: 10), "no Title row")

        // 1. Playhead at 12, Edit > Copy Frame: the pasteboard holds the 1920 x 1080 frame as a PNG.
        scrub(to: 12, halo)
        let pasteboard = NSPasteboard.general
        _ = pasteboard.clearContents()
        choose("Copy Frame", halo)
        XCTAssert(waitFor { pasteboard.data(forType: .png) != nil }, "Copy Frame put no PNG on the pasteboard")
        let frame = try XCTUnwrap(pasteboard.data(forType: .png).flatMap(NSBitmapImageRep.init(data:)), "the PNG won't decode")
        XCTAssertEqual(frame.pixelsWide, 1920, "the copied frame's width")
        XCTAssertEqual(frame.pixelsHigh, 1080, "the copied frame's height")
        halo.shot("edit-copy-frame")

        // 2. A 160 x 100 PNG on the pasteboard, Edit > Paste: one more layer, one step, at the playhead.
        XCTAssertFalse(halo.element(Self.pastedRow).exists, "Intro already has a fifth layer")
        _ = pasteboard.clearContents()
        XCTAssert(pasteboard.setData(try Self.png(width: 160, height: 100), forType: .png), "could not put a PNG on the pasteboard")
        choose("Paste", halo)
        XCTAssert(halo.element(Self.pastedRow).waitForExistence(timeout: 5), "Paste of a PNG added no layer row")
        expectUndo("Undo Paste", halo)
        expectTimecode(12, halo)
        halo.shot("edit-paste-image")
    }

    // MARK: Helpers

    /// Clicks Badge's title in the timeline (selects it and focuses the timeline), then Home and → `frame` times.
    @MainActor private func scrub(to frame: Int, _ halo: Journey) {
        let title = halo.trackName("Badge")
        XCTAssert(title.waitForExistence(timeout: 5), "no Badge track title in the timeline")
        title.click()
        halo.press(.home)
        for _ in 0..<frame { halo.press(.rightArrow) }
        expectTimecode(frame, halo)
    }

    /// The status timecode reads `frame` (Intro runs at 24 fps, so frames under 24 read as the last field).
    @MainActor private func expectTimecode(_ frame: Int, _ halo: Journey) {
        let timecode = String(format: "00:00:00:%02d", frame)
        let staticText = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let predicate = NSPredicate(
            format: "label BEGINSWITH %@ OR (elementType == %@ AND value BEGINSWITH %@)", timecode, staticText, timecode)
        let pill = halo.app.windows.firstMatch.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssert(pill.waitForExistence(timeout: 5), "the status timecode doesn't read \(timecode)")
    }

    /// Opens the Edit menu and clicks `item`.
    @MainActor private func choose(_ item: String, _ halo: Journey) {
        let edit = halo.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let entry = edit.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 3), "the Edit menu shows no \(item)")
        XCTAssert(entry.isEnabled, "Edit > \(item) is off")
        entry.click()
    }

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let edit = halo.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let first = edit.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        halo.press(.escape)
    }

    /// A solid blue PNG of `width` x `height` pixels.
    private static func png(width: Int, height: Int) throws -> Data {
        let rep = try XCTUnwrap(NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for x in 0..<width { for y in 0..<height { rep.setColor(.blue, atX: x, y: y) } }
        return try XCTUnwrap(rep.representation(using: .png, properties: [:]))
    }

    /// Whether `condition` holds within about five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
