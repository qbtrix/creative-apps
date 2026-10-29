// DesignJourneyTests+Hero.swift: the one-document hero (one-document OD-15), the captain's demo in one journey.
// A fresh profile, the top bar's New File, then a small UI: a frame, a line of text and a button rectangle, drawn
// last so it stays selected. The X and Opacity stopwatches (`design.inspector.key.x`, `.opacity`) animate the button
// from frame 0 to the last frame, and the timeline (`design.timeline`) slides in. A drag on its Frame Ruler moves
// the playhead to 120, X's diamond keys it there and a typed X auto-keys the new value, so the button moves. ⌥⌘P
// plays and pauses (the timecode `suite.transport.timecode` parks while playing and moves on pause), a ruler drag
// scrubs to 60, ⌘S saves through `-DesignSaveTo` (no panel) as a version 2 file, and a relaunch with
// `-DesignOpenFile` reopens it: one lane with its keys at 0, 120 and the last frame (`design.timeline.key.<id>.<f>`),
// and it plays again. A `snap` at each step makes the contact sheet (`design-hero-<step>`). Report-only, as every
// journey; it drives the real mouse and keyboard, so it runs in a journey window, never beside other work.
import XCTest

extension DesignJourneyTests {
    /// The document's last frame (DesignDocumentTime's default length, 300 frames).
    private static let heroLastFrame = 299.0

    @MainActor func testOneDocumentHero() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "design-hero-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "hero.design")
        let design = Journey("Design", self, arguments: ["-DesignSaveTo", file.path] + FirstFive.freshProfile())
        design.timeBox()
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        design.reachable("New File").click()
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "New File showed no canvas")

        // 1. A small UI: a frame, a title, and the button rectangle last, so it is the selection.
        heroDraw("Frame", from: CGVector(dx: 0.1, dy: 0.1), to: CGVector(dx: 0.7, dy: 0.8), design)
        design.reachable("Text", in: design.element("suite.tools")).click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.2), to: CGVector(dx: 0.2, dy: 0.2))
        design.app.typeText("Summer sale\r")
        XCTAssert(design.app.buttons["Undo Add Text"].waitForExistence(timeout: 5), "typing a title made no text")
        heroDraw("Rectangle", from: CGVector(dx: 0.2, dy: 0.55), to: CGVector(dx: 0.35, dy: 0.62), design)
        design.snap("hero-ui")

        // 2. The X and Opacity stopwatches animate the button; the first key slides the timeline in.
        let keyX = design.element("design.inspector.key.x"), keyOpacity = design.element("design.inspector.key.opacity")
        XCTAssert(keyX.waitForExistence(timeout: 5), "no X key button in the inspector (design.inspector.key.x)")
        keyX.click()
        XCTAssert(design.element("design.timeline").waitForExistence(timeout: 5), "the first key slid no timeline in")
        XCTAssert(keyOpacity.waitForExistence(timeout: 5), "no Opacity key button (design.inspector.key.opacity)")
        keyOpacity.click()
        XCTAssert(Self.heroWait { Self.heroText(keyOpacity) != "Not animated" }, "Opacity's stopwatch keyed nothing")
        design.snap("hero-keyed")

        // 3. Playhead to 120 on the ruler; X's diamond keys it, and a typed X moves the button there.
        let ruler = heroRuler(design)
        heroScrub(ruler, to: 120)
        let timecode = design.element("suite.transport.timecode")
        XCTAssert(timecode.waitForExistence(timeout: 5), "no timecode in the transport (suite.transport.timecode)")
        let at120 = Self.heroText(timecode)
        let diamondX = design.element("design.inspector.key.x.diamond")
        XCTAssert(diamondX.waitForExistence(timeout: 5), "an animated X shows no diamond")
        diamondX.click()
        XCTAssert(Self.heroWait { Self.heroText(keyX) == "Keyed at this frame" }, "X's diamond set no key at the playhead")
        let x = design.element("suite.inspector").descendants(matching: .any)["design.inspector.x"].firstMatch
        XCTAssert(x.waitForExistence(timeout: 5), "no X field in the inspector (design.inspector.x)")
        x.click()
        let field = x.textFields.firstMatch.waitForExistence(timeout: 2)
            ? x.textFields.firstMatch : design.element("suite.inspector").textFields.firstMatch
        design.press(character: "a", .command)
        field.typeText("520")
        design.press(.return)
        design.press(.escape)
        design.snap("hero-moved-at-120")

        // 4. Play and pause: the timecode leaves 120.
        heroPlayPause(design, from: at120, timecode)
        design.snap("hero-played")

        // 5. Scrub to 60: the button shows between its keys.
        heroScrub(ruler, to: 60)
        XCTAssert(Self.heroWait { Self.heroText(timecode) != at120 }, "scrubbing to 60 left the timecode at \(at120)")
        design.snap("hero-scrubbed-60")

        // 6. ⌘S: Saved, no panel, a version 2 file.
        design.press(character: "s", .command)
        XCTAssert(Self.heroWait { Self.heroText(design.element("design.status.save")) == "Saved" }, "⌘S didn't read Saved")
        XCTAssert(Self.heroWait { FileManager.default.fileExists(atPath: file.path) }, "⌘S wrote no file at -DesignSaveTo")
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
        XCTAssertEqual(json?["version"] as? Int, 2, "a keyed document didn't save as version 2")
        design.snap("hero-saved")
        design.app.terminate()

        // 7. Reopen: the timeline is back with one lane and its three keys, and it plays again.
        let reopened = Journey("Design", self, arguments: ["-DesignOpenFile", file.path] + FirstFive.freshProfile())
        let window = reopened.app.windows.matching(NSPredicate(format: "title BEGINSWITH 'hero'")).firstMatch
        XCTAssert(window.waitForExistence(timeout: 30), "hero.design didn't reopen")
        XCTAssert(reopened.element("design.timeline").waitForExistence(timeout: 10), "the reopened file shows no timeline")
        let all = reopened.app.descendants(matching: .any)
        let lanes = all.matching(NSPredicate(format: "identifier BEGINSWITH 'design.timeline.lane.'"))
        XCTAssert(Self.heroWait { lanes.count == 1 }, "the reopened timeline has \(lanes.count) lanes, not the button's one")
        for frame in [0, 120, Int(Self.heroLastFrame)] {
            let key = all.matching(NSPredicate(
                format: "identifier BEGINSWITH 'design.timeline.key.' AND identifier ENDSWITH %@", ".\(frame)")).firstMatch
            XCTAssert(key.waitForExistence(timeout: 5), "the reopened file lost the key at frame \(frame)")
        }
        reopened.snap("hero-reopened")
        let again = reopened.element("suite.transport.timecode")
        XCTAssert(again.waitForExistence(timeout: 5), "the reopened timeline has no timecode")
        heroPlayPause(reopened, from: Self.heroText(again), again)
        reopened.snap("hero-replayed")
    }

    /// Picks `tool` from the palette and drags it across the canvas: one Add step.
    @MainActor private func heroDraw(_ tool: String, from start: CGVector, to end: CGVector, _ design: Journey) {
        design.reachable(tool, in: design.element("suite.tools")).click()
        design.drag(on: "suite.canvas", from: start, to: end)
        XCTAssert(design.app.buttons["Undo Add \(tool)"].waitForExistence(timeout: 5), "drawing with \(tool) added nothing")
    }

    /// The timeline's Frame Ruler.
    @MainActor private func heroRuler(_ design: Journey) -> XCUIElement {
        let ruler = design.app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Frame Ruler'")).firstMatch
        XCTAssert(ruler.waitForExistence(timeout: 5), "no Frame Ruler in the timeline")
        return ruler
    }

    /// Drags the ruler's playhead to `frame` (FlareJourneyTests+Playback's ruler math).
    @MainActor private func heroScrub(_ ruler: XCUIElement, to frame: Int) {
        let width = (ruler.frame.width - 24) / Self.heroLastFrame
        let start = ruler.coordinate(withNormalizedOffset: .zero)
        start.withOffset(CGVector(dx: 8, dy: ruler.frame.height / 2)).press(
            forDuration: 0.1,
            thenDragTo: start.withOffset(CGVector(dx: 8 + Double(frame) * width, dy: ruler.frame.height / 2)))
    }

    /// ⌥⌘P plays for a second and ⌥⌘P pauses: the timecode, parked while playing, lands past `shown`.
    @MainActor private func heroPlayPause(_ design: Journey, from shown: String, _ timecode: XCUIElement) {
        design.press(character: "p", [.option, .command])
        Thread.sleep(forTimeInterval: 1)
        design.press(character: "p", [.option, .command])
        XCTAssert(Self.heroWait { Self.heroText(timecode) != shown }, "⌥⌘P twice left the timecode at \(shown)")
    }

    /// What an element reads: its value, else its label.
    @MainActor private static func heroText(_ element: XCUIElement) -> String {
        if let number = element.value as? NSNumber { return number.stringValue }
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// Whether `condition` holds within five seconds.
    @MainActor private static func heroWait(_ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(5)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return condition()
    }
}
