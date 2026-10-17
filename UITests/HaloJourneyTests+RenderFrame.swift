// HaloJourneyTests+RenderFrame.swift: H-J20, Render Frame (render-out RO-9,
// #451; docs/blueprints/halo/features/render-out.md, Journey steps 1). On
// `-HaloSample parented` (Bounce on live services, 48 frames at 24 fps: Rig,
// a null keyed on x, over Ball and Floor) it scrubs to 12 and presses ⌘R,
// scrubs to 13, back to 12, then to 13 and presses ⌘R again. The rendered
// frame is `halo.viewer.rendered` (HaloRenderedFrameView.swift), an image
// labelled "Rendered frame" whose value is the Model's renderedFrameSummary
// ("Rendered frame 12 at 480 × 270"); its note is `halo.viewer.renderedNote`,
// labelled with renderedFrameNote ("Rendered frame is out of date." when
// stale, else the frame's undrawn-text note). After each ⌘R there is no
// note: Rig is a null and is never counted as a skipped layer (#457). A
// value XCUITest reads empty (#262) can't be compared, so then the frame is
// read from the label of the artboard's `halo.viewer.summary` ("Frame 12:
// …") and the missing note proves the shown frame is that one; a value that
// reads anything else fails. The size, 480 × 270, is HaloModelTests'
// HaloRenderFrameTests' to prove in that case. The playhead moves from the
// keys: clicking Ball's title in the timeline focuses it, then Home and →,
// read on the status timecode, as H-J7 does. Render Frame is pressed as ⌘R,
// File's shortcut; it records no undo step. The Model half of every step is
// HaloRenderFrameTests. One shot per step, `halo-render-frame-<n>-<step>`.
import XCTest

final class HaloRenderFrameJourneyTests: XCTestCase {
    private static let renderedID = "halo.viewer.rendered", noteID = "halo.viewer.renderedNote"
    private static let stale = "Rendered frame is out of date."

    /// H-J20: render the frame at the playhead, see it go stale on a scrub
    /// and fresh again on scrubbing back, then render the next frame.
    @MainActor func testRenderFrame() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "parented", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Scrub to 12 and press ⌘R: the rendered frame 12 at 480 × 270, no note.
        scrub(to: 12, halo)
        halo.press(character: "r", .command)
        expectRendered(frame: 12, halo)
        expectNoNote("a fresh render of frame 12 (Rig is a null, never skipped: #457)", halo)
        halo.shot("render-frame-1-rendered")

        // 2. Scrub to 13: the note reads "Rendered frame is out of date."
        scrub(to: 13, halo)
        expectNote(reads: Self.stale, halo)
        halo.shot("render-frame-2-stale")

        // 3. Scrub back to 12: the note is gone.
        scrub(to: 12, halo)
        expectRendered(frame: 12, halo)
        expectNoNote("scrubbing back to the rendered frame 12", halo)
        halo.shot("render-frame-3-fresh-again")

        // 4. Scrub to 13 and press ⌘R: the rendered frame 13, no note.
        scrub(to: 13, halo)
        expectNote(reads: Self.stale, halo)
        halo.press(character: "r", .command)
        expectRendered(frame: 13, halo)
        expectNoNote("a fresh render of frame 13", halo)
        halo.shot("render-frame-4-rerendered")
    }

    // MARK: - Helpers

    /// `halo.viewer.rendered` shows, the artboard's summary names `frame`,
    /// and the image's value reads "Rendered frame <frame> at 480 × 270"
    /// within three seconds. A value that stays empty (#262) is let through
    /// (the caller's note check proves the frame is current); any other
    /// value fails.
    @MainActor private func expectRendered(frame: Int, _ halo: Journey) {
        let rendered = halo.element(Self.renderedID)
        XCTAssert(rendered.waitForExistence(timeout: 10), "the viewer shows no rendered frame (\(Self.renderedID))")
        let summary = halo.element("halo.viewer.summary")
        XCTAssert(
            waitFor { summary.label.hasPrefix("Frame \(frame):") },
            "the artboard reads \(summary.label), not frame \(frame)")
        let want = "Rendered frame \(frame) at 480 × 270"
        func value() -> String { rendered.value as? String ?? "" }
        if waitFor({ value() == want || rendered.label == want }) { return }
        XCTAssert(value().isEmpty, "the rendered frame reads \(value()), not \(want)")
    }

    /// `halo.viewer.renderedNote` reads `text` within three seconds.
    @MainActor private func expectNote(reads text: String, _ halo: Journey) {
        let note = halo.element(Self.noteID)
        XCTAssert(note.waitForExistence(timeout: 5), "the rendered frame shows no note (\(Self.noteID))")
        XCTAssert(
            waitFor { note.label == text || (note.value as? String) == text },
            "the rendered frame's note reads \(note.label), not \(text)")
    }

    /// No `halo.viewer.renderedNote` shows within three seconds; `when` names the step.
    @MainActor private func expectNoNote(_ when: String, _ halo: Journey) {
        let note = halo.element(Self.noteID)
        XCTAssert(waitFor { !note.exists }, "after \(when) the rendered frame has a note: \(note.label)")
        // A note that comes a moment late (a skipped layer) still fails.
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(note.exists, "after \(when) a note appeared: \(note.label)")
    }

    /// Clicks Ball's title in the timeline (selects Ball and focuses the
    /// timeline; selection isn't the composition, so it never stales the
    /// frame), then Home and → `frame` times; the status timecode reads the frame.
    @MainActor private func scrub(to frame: Int, _ halo: Journey) {
        let title = halo.app.buttons.matching(
            NSPredicate(format: "identifier == 'halo.timeline.track' AND label == 'Ball'")).firstMatch
        XCTAssert(title.waitForExistence(timeout: 10), "no Ball track title in the timeline")
        title.click()
        halo.press(.home)
        for _ in 0..<frame { halo.press(.rightArrow) }
        // Bounce runs at 24 fps, so frames under 24 read as the last field.
        let timecode = String(format: "00:00:00:%02d", frame)
        let staticText = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let predicate = NSPredicate(
            format: "label BEGINSWITH %@ OR (elementType == %@ AND value BEGINSWITH %@)", timecode, staticText, timecode)
        let pill = halo.app.windows.firstMatch.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssert(pill.waitForExistence(timeout: 5), "the status timecode doesn't read \(timecode)")
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
