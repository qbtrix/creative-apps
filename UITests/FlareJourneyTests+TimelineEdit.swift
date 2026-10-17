// FlareJourneyTests+TimelineEdit.swift: J11 (inspector-timeline IT-7) on `-FlareSample bounce` (Ball keyed at 0, 12,
// 24, 36, 47): drag key 24 to 28 (Edit menu: Undo Move Keyframe), select 12 and Delete, at 10 Option-= twice and
// Option-minus once (28 to 30 to 29), at 29 Add Label… "hit" from the context menu (on the ruler at 29), each one
// Command-Z and back with Shift-Command-Z; then a drag of 29 onto 37 is refused with its reason. Keys are the lane's
// "Key at frame N" children; a ruler frame's x is 8 pt in plus its share of the width less 24. Shots `flare-j11-*`.
import XCTest

final class FlareTimelineEditJourneys: XCTestCase {
    /// J11: retime, delete, insert and remove frames, and label on Ball's lane, each one undo step.
    @MainActor func testRetimeDeleteInsertAndLabel() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(key(24, flare).waitForExistence(timeout: 10), "Ball's lane has no key at 24")
        flare.shot("j11-0-open")

        // 1. Drag key 24 four frames right: it lands on 28, one "Undo Move Keyframe" in the Edit menu.
        let step = (key(24, flare).frame.midX - key(12, flare).frame.midX) / 12
        let grab = key(24, flare).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grab.press(forDuration: 0.2, thenDragTo: grab.withOffset(CGVector(dx: 4 * step, dy: 0)))
        expectKeys([0, 12, 28, 36, 47], "after the drag", flare)
        flare.app.menuBars.menuBarItems["Edit"].click()
        let undoMove = flare.app.menuBars.menuItems["Undo Move Keyframe"]
        XCTAssert(undoMove.waitForExistence(timeout: 5), "the Edit menu has no Undo Move Keyframe")
        undoMove.click()
        expectKeys([0, 12, 24, 36, 47], "after Undo Move Keyframe", flare)
        flare.press(character: "z", [.command, .shift])
        expectKeys([0, 12, 28, 36, 47], "after redoing the move", flare)
        flare.shot("j11-1-moved")

        // 2. Select key 12 and press Delete: it is gone, one undo.
        key(12, flare).click()
        XCTAssert(waitFor { self.key(12, flare).isSelected }, "clicking key 12 didn't select it")
        flare.press(.delete)
        expectKeys([0, 28, 36, 47], "after Delete", flare)
        undoAndRedo([0, 12, 28, 36, 47], [0, 28, 36, 47], "the delete", flare)
        flare.shot("j11-2-deleted")

        // 3. At frame 10, Option-= twice: 28 moves to 30; each is one undo.
        scrub(to: 10, flare)
        flare.press(character: "=", .option)
        expectKeys([0, 29, 37, 48], "after one Insert Frame", flare)
        undoAndRedo([0, 28, 36, 47], [0, 29, 37, 48], "Insert Frame", flare)
        flare.press(character: "=", .option)
        expectKeys([0, 30, 38, 49], "after two Insert Frames", flare)
        flare.shot("j11-3-inserted")

        // 4. Option-minus once: 30 moves back to 29.
        flare.press(character: "-", .option)
        expectKeys([0, 29, 37, 48], "after Remove Frame", flare)
        undoAndRedo([0, 30, 38, 49], [0, 29, 37, 48], "Remove Frame", flare)
        flare.shot("j11-4-removed")

        // 5. At 29, Add Label… from the context menu, named "hit": it reads on the ruler at 29.
        scrub(to: 29, flare)
        lane(flare).rightClick()
        let addLabel = flare.app.menuItems["Add Label…"]
        XCTAssert(addLabel.waitForExistence(timeout: 5), "the timeline's context menu has no Add Label…")
        XCTAssert(flare.app.menuItems["Delete Keyframe"].exists, "the timeline's context menu has no Delete Keyframe")
        flare.shot("j11-5-context-menu")
        addLabel.click()
        let name = flare.element("flare.timeline.labelName")
        XCTAssert(name.waitForExistence(timeout: 5), "Add Label… asked for no name")
        name.typeText("hit\r")
        let label = flare.app.descendants(matching: .any).matching(
            NSPredicate(format: "label == 'Label hit at frame 29'")).firstMatch
        XCTAssert(label.waitForExistence(timeout: 5), "no label \"hit\" at frame 29 on the ruler")
        flare.shot("j11-5-labelled")
        flare.press(character: "z", .command)
        XCTAssert(waitFor { !label.exists }, "Command-Z left the label")
        flare.press(character: "z", [.command, .shift])
        XCTAssert(label.waitForExistence(timeout: 5), "Shift-Command-Z didn't bring the label back")

        // 6. Drag key 29 onto Ball's next key at 37: refused, the reason shows, and Ball keeps four keys.
        let middle = CGVector(dx: 0.5, dy: 0.5)
        key(29, flare).coordinate(withNormalizedOffset: middle).press(
            forDuration: 0.2, thenDragTo: key(37, flare).coordinate(withNormalizedOffset: middle))
        XCTAssert(flare.element("flare.timeline.error").waitForExistence(timeout: 5), "a drag onto 37 showed no reason")
        XCTAssert(keys(flare).contains(37) && keys(flare).count == 4, "the refused drag left Ball's keys at \(keys(flare).sorted())")
        flare.shot("j11-6-refused")
    }

    /// Ball's lane: the element named Ball that isn't its name button.
    @MainActor private func lane(_ flare: Journey) -> XCUIElement {
        flare.element("flare.timeline").descendants(matching: .any).matching(
            NSPredicate(format: "label == 'Ball' AND elementType != %d", XCUIElement.ElementType.button.rawValue)).firstMatch
    }

    @MainActor private func key(_ frame: Int, _ flare: Journey) -> XCUIElement {
        lane(flare).descendants(matching: .any).matching(
            NSPredicate(format: "label BEGINSWITH %@", "Key at frame \(frame),")).firstMatch
    }

    @MainActor private func keys(_ flare: Journey) -> [Int] {
        lane(flare).descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Key at frame '"))
            .allElementsBoundByIndex.compactMap { Int($0.label.dropFirst("Key at frame ".count).prefix { $0.isNumber }) }
            .sorted()
    }

    @MainActor private func expectKeys(_ frames: [Int], _ when: String, _ flare: Journey) {
        let matched = waitFor { self.keys(flare) == frames }
        if !matched { flare.attachTree(as: "j11-keys-tree") }
        XCTAssert(matched, "Ball's keys read \(keys(flare)) \(when), not \(frames)")
    }

    /// Command-Z puts `before` back; Shift-Command-Z redoes to `after`.
    @MainActor private func undoAndRedo(_ before: [Int], _ after: [Int], _ what: String, _ flare: Journey) {
        flare.press(character: "z", .command)
        expectKeys(before, "after undoing \(what)", flare)
        flare.press(character: "z", [.command, .shift])
        expectKeys(after, "after redoing \(what)", flare)
    }

    /// Drags the playhead on the Frame Ruler from 0 to `target`.
    @MainActor private func scrub(to target: Int, _ flare: Journey) {
        let ruler = flare.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        let readout = flare.element("flare.timeline.frame")
        let total = Double(readout.label.split(separator: "/").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? "") ?? 48
        let corner = ruler.coordinate(withNormalizedOffset: .zero), step = (ruler.frame.width - 24) / max(total - 1, 1)
        func x(_ frame: Int) -> CGVector { CGVector(dx: 8 + Double(frame) * step, dy: ruler.frame.height / 2) }
        corner.withOffset(x(0)).press(forDuration: 0.1, thenDragTo: corner.withOffset(x(target)))
        XCTAssert(waitFor { Int(readout.label.prefix { $0.isNumber }) == target },
                  "the frame reads \(readout.label) after the scrub, not \(target)")
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}
