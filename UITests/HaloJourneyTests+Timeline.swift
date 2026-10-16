// HaloJourneyTests+Timeline.swift: clicking keys and bars on Halo's timeline,
// with the mouse, as a person would (the 2026-10-16 timeline review, B1, B2
// and B5). On `-HaloSample keyed` (Bounce: Ball keyed on x at 0 and 24 and on
// opacity at 0 and 12, over Floor) it clicks Ball's diamond at 24, which
// picks Position X, frames 0–24 in EASING; presses ⌫, which deletes that key
// as one "Delete Keyframes" step and leaves Ball in the layer list with 2
// keyframes; undoes it; then clicks Floor's span bar, away from any key,
// which selects Floor. Diamonds and bars have no element of their own, so a
// point is the Frame Ruler's left edge plus the strip's 8 pt inset and the
// frame's share of the ruler's width (its last frame, 47, sits 24 pt before
// the ruler's right edge), on the row of the lane's name button
// (`halo.timeline.track`). A lane's key count is the hidden
// `halo.timeline.keys` element's label ("Ball: 3 keyframes", #262). The Model
// half is HaloKeySelectionTests. One shot per step, `halo-timeline-<step>`.
import XCTest

final class HaloTimelineJourneyTests: XCTestCase {
    private static let ball = "comp-1-layer-2", floor = "comp-1-layer-1"
    private static let lastFrame = 47.0

    /// Pick a key from its diamond, delete it with ⌫, undo, then select a layer from its bar.
    @MainActor func testClickKeysAndBars() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "keyed", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(keys("Ball", halo).waitForExistence(timeout: 10), "no key count for Ball (halo.timeline.keys)")
        XCTAssertEqual(keys("Ball", halo).label, "Ball: 3 keyframes", "Ball's keys before any click")

        // 1. Click Ball's diamond at 24: Ball is selected and Position X, frames 0–24 is picked.
        click(frame: 24, lane: "Ball", halo)
        let xRow = halo.element("halo.easing.key.x.0")
        XCTAssert(xRow.waitForExistence(timeout: 5), "EASING has no Position X row after clicking Ball's key")
        XCTAssert(waitFor { xRow.isSelected }, "clicking Ball's key at 24 didn't pick Position X, frames 0–24")
        halo.shot("timeline-1-pick-key")

        // 2. ⌫ deletes the key, not the layer: Ball stays, with 2 keyframes.
        halo.press(.delete)
        XCTAssert(waitFor { self.keys("Ball", halo).label == "Ball: 2 keyframes" }, "⌫ left \(keys("Ball", halo).label)")
        XCTAssert(halo.element("halo.layer.row.\(Self.ball)").exists, "⌫ with a key picked deleted Ball")
        expectUndo("Undo Delete Keyframes", halo)
        halo.shot("timeline-2-delete-key")

        // 3. ⌘Z brings the key back.
        halo.press(character: "z", .command)
        XCTAssert(waitFor { self.keys("Ball", halo).label == "Ball: 3 keyframes" }, "⌘Z left \(keys("Ball", halo).label)")
        halo.shot("timeline-3-undo")

        // 4. Click Floor's bar at frame 30, where it has no key: Floor is selected.
        click(frame: 30, lane: "Floor", halo)
        let floorRow = halo.element("halo.layer.row.\(Self.floor)")
        XCTAssert(floorRow.waitForExistence(timeout: 5), "no Floor row (halo.layer.row.\(Self.floor))")
        XCTAssert(waitFor { floorRow.isSelected }, "clicking Floor's bar didn't select Floor")
        halo.shot("timeline-4-click-bar")
    }

    // MARK: - Helpers

    /// The hidden key count of `name`'s lane.
    @MainActor private func keys(_ name: String, _ halo: Journey) -> XCUIElement {
        halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.timeline.keys' AND label BEGINSWITH %@", "\(name):")
        ).firstMatch
    }

    /// Clicks the mouse on `frame` of `name`'s lane.
    @MainActor private func click(frame: Int, lane name: String, _ halo: Journey) {
        let ruler = halo.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        let title = halo.app.buttons.matching(
            NSPredicate(format: "identifier == 'halo.timeline.track' AND label == %@", name)).firstMatch
        XCTAssert(title.waitForExistence(timeout: 5), "no \(name) track title in the timeline")
        let frameWidth = (ruler.frame.width - 24) / Self.lastFrame
        let x = 8 + Double(frame) * frameWidth
        let y = title.frame.midY - ruler.frame.minY
        ruler.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).click()
    }

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let edit = halo.app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssert(edit.waitForExistence(timeout: 5), "no Edit menu")
        edit.click()
        let first = edit.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        halo.press(.escape)
        XCTAssert(halo.menusClosed(), "the Edit menu stayed open after Escape")
    }

    /// Whether `condition` holds within three seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
