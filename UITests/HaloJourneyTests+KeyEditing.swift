// HaloJourneyTests+KeyEditing.swift: MJ-KE, pick keys across layers, select
// them all and move them (key-editing KE-5 written, KE-7 turned on;
// docs/blueprints/halo/features/key-editing.md, Journey steps). On
// `-HaloFixture parented` (Rig keyed on x at 0 and 47, Ball at 0, 12 and 24,
// Floor unkeyed): click Ball's key at 0, Shift-click Rig's, drag Ball's 6
// frames right (both land at 6, Edit reads "Undo Move Keyframes"), ⌘Z, hide
// Rig and ⌘A in the timeline, Animation > Select All Keys, drag Ball's key at
// 0 alone onto 12 (refused, the status line says why), then ⌘A, ⌫ and ⌘Z.
// A key is `halo.timeline.key.<layer id>.<frame>`, selected while picked
// (TimelineLaneAccess). Halo has no eye yet, so step 5 hides Rig only when
// its row shows one. One shot per step, `key-editing-<step>`. It skips until
// KE-7, when the moves (KE-4) are on dev.
import XCTest

final class HaloKeyEditingJourneyTests: XCTestCase {
    private static let rig = "comp-1-layer-3", ball = "comp-1-layer-2"

    @MainActor func testSelectAllAndMoveKeys() throws {
        try XCTSkipIf(true, "waits on KE-7")
        let halo = Journey("Halo", self, arguments: ["-HaloFixture", "parented", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Click Ball's key at 0: it draws picked and Ball is selected.
        let ball0 = key(Self.ball, 0, halo), rig0 = key(Self.rig, 0, halo)
        XCTAssert(ball0.waitForExistence(timeout: 10), "no key for Ball at 0")
        ball0.click()
        XCTAssert(waitFor { ball0.isSelected }, "a click on Ball's key at 0 didn't pick it")
        XCTAssert(halo.element("halo.layer.row.\(Self.ball)").isSelected, "picking Ball's key didn't select Ball")
        halo.shot("key-editing-1-pick-ball")

        // 2. Shift-click Rig's key at 0: keys on two lanes draw picked.
        XCUIElement.perform(withKeyModifiers: .shift) { rig0.click() }
        XCTAssert(waitFor { ball0.isSelected && rig0.isSelected }, "Shift-click didn't add Rig's key at 0")
        halo.shot("key-editing-2-pick-across")

        // 3. Drag Ball's key 6 frames right: both land at 6, one Move Keyframes step.
        let ball12 = key(Self.ball, 12, halo)
        let frame = (ball12.frame.midX - ball0.frame.midX) / 12
        let grab = ball0.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grab.press(forDuration: 0.1, thenDragTo: grab.withOffset(CGVector(dx: 6 * frame, dy: 0)))
        XCTAssert(key(Self.ball, 6, halo).waitForExistence(timeout: 5), "Ball's key didn't land at 6")
        XCTAssert(key(Self.rig, 6, halo).exists, "Rig's key didn't move with Ball's")
        expectUndo("Undo Move Keyframes", halo)
        halo.shot("key-editing-3-move")

        // 4. ⌘Z: both keys are back at 0, in one step.
        halo.press(character: "z", .command)
        XCTAssert(ball0.waitForExistence(timeout: 5) && rig0.exists, "one ⌘Z didn't bring both keys back to 0")
        halo.shot("key-editing-4-undo")

        // 5. Hide Rig, click the timeline, ⌘A: every key on every lane draws picked, the hidden Rig's too.
        let eye = halo.element("halo.layer.\(Self.rig).eye")
        if eye.exists { eye.click() }
        halo.trackName("Ball").click()
        halo.press(character: "a", .command)
        expectEveryKeyPicked(halo)
        halo.shot("key-editing-5-select-all")
        halo.trackName("Ball").click()
        let animation = halo.app.menuBars.firstMatch.menuBarItems["Animation"]
        animation.click()
        let selectAll = animation.menus.firstMatch.children(matching: .menuItem)["Select All Keys"]
        XCTAssert(selectAll.waitForExistence(timeout: 3) && selectAll.isEnabled, "Animation > Select All Keys is off")
        selectAll.click()
        expectEveryKeyPicked(halo)

        // 6. Ball's key at 0 alone onto 12: nothing moves, and the status line says why.
        ball0.click()
        ball0.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: ball12.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        let refusal = "A key is already at frame 12 on Ball."
        let line = halo.app.windows.firstMatch.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", refusal, refusal)).firstMatch
        XCTAssert(line.waitForExistence(timeout: 5), "the status line doesn't read \(refusal)")
        XCTAssert(ball0.exists && ball12.exists, "the refused move moved Ball's keys")
        halo.shot("key-editing-6-refused")

        // 7. ⌘A, ⌫: every key goes in one Delete Keyframes step; ⌘Z brings them back.
        halo.press(character: "a", .command)
        halo.press(.delete)
        XCTAssert(waitFor { !ball0.exists && !rig0.exists && !ball12.exists }, "⌫ left keys after ⌘A")
        expectUndo("Undo Delete Keyframes", halo)
        halo.press(character: "z", .command)
        XCTAssert(ball0.waitForExistence(timeout: 5) && rig0.exists && ball12.exists, "⌘Z didn't bring the keys back")
        halo.shot("key-editing-7-delete-undo")
    }

    // MARK: - Helpers

    /// The key of `layer` at `frame` on the timeline.
    @MainActor private func key(_ layer: String, _ frame: Int, _ halo: Journey) -> XCUIElement {
        halo.element("halo.timeline.key.\(layer).\(frame)")
    }

    /// Ball's keys at 0, 12 and 24 and Rig's at 0 and 47 all draw picked.
    @MainActor private func expectEveryKeyPicked(_ halo: Journey) {
        let keys = [0, 12, 24].map { key(Self.ball, $0, halo) } + [0, 47].map { key(Self.rig, $0, halo) }
        XCTAssert(waitFor { keys.allSatisfy { $0.isSelected } }, "not every key is picked after Select All Keys")
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
