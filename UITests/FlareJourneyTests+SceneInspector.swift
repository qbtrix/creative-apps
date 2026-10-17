// FlareJourneyTests+SceneInspector.swift: step 3 of inspector-timeline
// (IT-6). On `-FlareSample bounce` with nothing selected the SCENE section
// reads the sample's 550 × 400, 24 fps and 48 frames, and the timecode
// totals 02:00.
// Frame Rate's menu picks 30 fps: the row reads 30 fps and the total changes
// (48 frames at 30 fps is 01:18). ⌘Z restores 24 fps and 02:00. The Frame
// Rate row carries `flare.inspector.scene.fps` and "<n> fps" as its value; its
// menu is found as a menu, pop-up or plain button with that id or the label
// "Frame Rate". Shots: `flare-scene-<step>`.
import XCTest

final class FlareSceneInspectorJourneys: XCTestCase {
    /// SCENE reads the sample's size, rate and length; 30 fps lands, changes the total and undoes.
    @MainActor func testSceneSection() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Nothing selected: SCENE shows 550 × 400, 24 fps, 48 frames; the total is 02:00.
        let scene = flare.element("flare.inspector.scene")
        XCTAssert(scene.waitForExistence(timeout: 10), "no SCENE section (flare.inspector.scene)")
        expectNumber(550, of: "flare.inspector.scene.width", flare)
        expectNumber(400, of: "flare.inspector.scene.height", flare)
        expectNumber(48, of: "flare.inspector.scene.duration", flare)
        expectRate(24, flare)
        let timecode = flare.element("flare.timeline.timecode")
        XCTAssert(timecode.waitForExistence(timeout: 5), "no timecode (flare.timeline.timecode)")
        XCTAssert(timecode.label.hasSuffix("/ 02:00"), "the timecode reads \(timecode.label), not a 02:00 total")
        flare.shot("scene-1-open")

        // 2. Frame Rate → 30 fps: the row reads 30 and the total is no longer 02:00.
        let picker = flare.element("suite.inspector").descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@ AND (identifier == 'flare.inspector.scene.fps' OR label == 'Frame Rate')",
                        [XCUIElement.ElementType.menuButton, .popUpButton, .button].map { NSNumber(value: $0.rawValue) })
        ).firstMatch
        XCTAssert(picker.waitForExistence(timeout: 5), "no Frame Rate menu (flare.inspector.scene.fps)")
        picker.click()
        let thirty = flare.app.menuItems.matching(NSPredicate(format: "title == '30 fps'")).firstMatch
        XCTAssert(thirty.waitForExistence(timeout: 5), "the Frame Rate menu offers no 30 fps")
        thirty.click()
        expectRate(30, flare)
        XCTAssert(waitFor { !timecode.label.hasSuffix("/ 02:00") },
                  "the timecode still totals 02:00 at 30 fps: \(timecode.label)")
        flare.shot("scene-2-30fps")

        // 3. ⌘Z: back to 24 fps and a 02:00 total.
        flare.press(character: "z", .command)
        expectRate(24, flare)
        XCTAssert(waitFor { timecode.label.hasSuffix("/ 02:00") }, "⌘Z left the timecode at \(timecode.label)")
        flare.shot("scene-3-undo")
    }

    /// The Frame Rate row reads "`fps` fps" within five seconds.
    @MainActor private func expectRate(_ fps: Int, _ flare: Journey) {
        let row = flare.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'flare.inspector.scene.fps' AND value == %@", "\(fps) fps")).firstMatch
        XCTAssert(row.waitForExistence(timeout: 5),
                  "Frame Rate reads \(String(describing: flare.element("flare.inspector.scene.fps").value)), not \(fps) fps")
    }

    /// The bar `id` reads `number`: its slider value, or the first number in its text ("1920 px").
    @MainActor private func expectNumber(_ number: Double, of id: String, _ flare: Journey) {
        let bar = flare.element(id)
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(id)")
        func reading() -> Double? {
            if let value = bar.value as? NSNumber { return value.doubleValue }
            let text = (bar.value as? String) ?? ""
            return text.range(of: #"[0-9]+(\.[0-9]+)?"#, options: .regularExpression).flatMap { Double(text[$0]) }
        }
        XCTAssert(waitFor { reading() == number }, "\(id) reads \(String(describing: bar.value)), not \(number)")
    }

    /// Polls `condition` for up to five seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 where !condition() { Thread.sleep(forTimeInterval: 0.2) }
        return condition()
    }
}
