// FlareJourneyTests+LottieOpen.swift (lottie-open LO-2 written, LO-5 turned on): opening a Lottie file and
// recolouring it, as a person does. Each launch opens a copy of a fixture with `-FlareOpenFile`, the way Open
// Recent opens a file (the open panel can't be driven), with `-FlareExportTo` and `-FlareSaveTo` on this test's
// own temp folders, so Export and Save write with no panel:
// 1. bounce.json (RJ-F12's input): the window reads "Untitled", the note above the stage (`flare.import.note`)
//    says "Nothing was skipped."; Close (`flare.import.dismiss`) takes it away.
// 2. Select Ball from its timeline track and type FF8000 into FILL's hex: it reads back; Undo takes it back, Redo
//    puts it back.
// 3. Export Lottie: scene-1.json has the ball's three position keys and an orange `fl.c`.
// 4. Save: a .flare lands in the save folder, never a .json, and the opened JSON's bytes are unchanged.
// 5. precomp.lottie.json: the note names the precomp and the image left out; Close takes it away.
// The stage isn't compared: it draws an opened file's colour only once the stage-matches-export fix lands (the
// packet's Waits), so the recolour is checked in the export. Shots are `flare-lottie-<step>`.
import XCTest

final class FlareLottieOpenJourneyTests: XCTestCase {
    static let arguments = ["-FlareServices", "live", "-SuiteWindowSize", "1024x768"]
    static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    static let bounce = repo.appending(path: "Tests/RealJobs/flare/open-recolour-lottie/input/bounce.json")
    static let precomp = repo.appending(path: "Tests/FlareModelTests/Fixtures/Lottie/precomp.lottie.json")

    @MainActor func testOpenAndRecolour() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-lottie-\(UUID().uuidString)")
        let exports = folder.appending(path: "exports"), saves = folder.appending(path: "saves")
        for dir in [exports, saves] { try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let input = folder.appending(path: "bounce.json"), original = try Data(contentsOf: Self.bounce)
        try original.write(to: input)

        // 1. Open bounce.json: untitled, the note says nothing was skipped; Close.
        var flare = Journey("Flare", self, arguments: Self.arguments
            + ["-FlareOpenFile", input.path, "-FlareExportTo", exports.path, "-FlareSaveTo", saves.path])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        expectNote(reading: ["Nothing was skipped."], flare)
        let window = flare.app.windows.firstMatch
        XCTAssert(waitFor { window.title == "Untitled" }, "the window is titled \(window.title), not Untitled")
        flare.shot("lottie-1-opened")
        dismissNote(flare)

        // 2. Ball's fill to FF8000; Undo, Redo.
        let ball = flare.element("flare.timeline").buttons.matching(NSPredicate(format: "label == 'Ball'")).firstMatch
        XCTAssert(ball.waitForExistence(timeout: 10), "no Ball track in the timeline")
        ball.click()
        let fill = flare.element("flare.inspector.fill")
        XCTAssert(fill.waitForExistence(timeout: 5), "selecting Ball showed no FILL row")
        let hex = fill.textFields.firstMatch
        XCTAssert(hex.waitForExistence(timeout: 5), "the FILL row has no hex field")
        hex.click()
        flare.app.typeKey(.rightArrow, modifierFlags: .command)
        for _ in 0..<12 { flare.app.typeKey(.delete, modifierFlags: []) }
        flare.app.typeText("FF8000")
        flare.press(.return)
        let orange = { ((hex.value as? String) ?? "").uppercased().contains("FF8000") }
        XCTAssert(waitFor(orange), "the fill reads \(String(describing: hex.value)), not FF8000")
        flare.shot("lottie-2-orange")
        flare.press(character: "z", .command)
        XCTAssert(waitFor { !orange() }, "Undo left the fill FF8000")
        flare.press(character: "z", [.command, .shift])
        XCTAssert(waitFor(orange), "Redo didn't put FF8000 back")

        // 3. Export Lottie: three position keys on the ball, fl.c orange.
        let export = flare.app.toolbars.firstMatch.buttons["flare.export.showSheet"]
        XCTAssert(export.waitForExistence(timeout: 10) && waitFor { export.isEnabled }, "Export… is missing or disabled")
        export.click()
        let lottie = flare.element("flare.export.format.lottie")
        XCTAssert(lottie.waitForExistence(timeout: 5), "the sheet has no Lottie chip (flare.export.format.lottie)")
        lottie.click()
        flare.element("flare.export.start").click()
        let json = exports.appending(path: "scene-1.json")
        XCTAssert(waitFor { FileManager.default.fileExists(atPath: json.path) }, "Export wrote no scene-1.json")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: json))
        let layers = (root as? [String: Any])?["layers"] as? [[String: Any]] ?? []
        let ballLayer = try XCTUnwrap(layers.first { $0["nm"] as? String == "Ball" }, "the export has no Ball layer")
        XCTAssertEqual(Self.positionKeys(ballLayer), 3, "the ball's position keys changed in the export")
        let colour = try XCTUnwrap(Self.fillColours(ballLayer).first, "the ball has no fl in the export")
        XCTAssertEqual(colour.count, 4)
        for (got, want) in zip(colour, [1, 0.5, 0, 1]) { XCTAssertEqual(got, want, accuracy: 0.01, "fl.c is \(colour)") }
        let done = flare.element("flare.export.dismiss")
        XCTAssert(waitFor { done.exists }, "the run never finished (no Done)")
        done.click()
        flare.shot("lottie-3-exported")

        // 4. Save: a .flare, never the JSON; the JSON's bytes unchanged.
        flare.press(character: "s", .command)
        let saved = { (try? FileManager.default.contentsOfDirectory(atPath: saves.path)) ?? [] }
        XCTAssert(waitFor { saved().contains { $0.hasSuffix(".flare") } }, "Save wrote \(saved()), no .flare")
        XCTAssertFalse(saved().contains { $0.hasSuffix(".json") }, "Save wrote a .json: \(saved())")
        XCTAssertEqual(try Data(contentsOf: input), original, "Save changed the opened bounce.json")
        flare.shot("lottie-4-saved")
        flare.app.terminate()

        // 5. precomp: the note names the precomp and the image; Close.
        let precomp = folder.appending(path: "precomp.json")
        try Data(contentsOf: Self.precomp).write(to: precomp)
        flare = Journey("Flare", self, arguments: Self.arguments + ["-FlareOpenFile", precomp.path])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened for precomp.json")
        expectNote(reading: ["The precomp \"Logo\"", "The image \"Photo\""], flare)
        flare.shot("lottie-5-skipped")
        dismissNote(flare)
    }

    // MARK: - Helpers

    /// The note above the stage shows a row containing each of `texts`.
    @MainActor private func expectNote(reading texts: [String], _ flare: Journey) {
        let note = flare.element("flare.import.note")
        XCTAssert(note.waitForExistence(timeout: 20), "the Lottie open showed no note (flare.import.note)")
        for text in texts {
            // Each row is an InspectorNote, one element with its children ignored and its text as the label, so it
            // need not reach XCUITest as a static text: match any descendant by label or value (#4954).
            let row = note.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
            XCTAssert(row.firstMatch.waitForExistence(timeout: 5), "the note doesn't read \"\(text)\"")
        }
    }

    /// Close on the note: the note goes.
    @MainActor private func dismissNote(_ flare: Journey) {
        let close = flare.element("flare.import.dismiss")
        XCTAssert(close.waitForExistence(timeout: 5), "the note has no Close (flare.import.dismiss)")
        close.click()
        XCTAssert(flare.element("flare.import.note").waitForNonExistence(timeout: 5), "Close left the note up")
    }

    /// A Lottie layer's position keys: `ks.p.k` when it is one keyed property, else `ks.p.x.k` (split position).
    private static func positionKeys(_ layer: [String: Any]) -> Int? {
        guard let p = (layer["ks"] as? [String: Any])?["p"] as? [String: Any] else { return nil }
        if let keys = p["k"] as? [[String: Any]] { return keys.count }
        return ((p["x"] as? [String: Any])?["k"] as? [[String: Any]])?.count
    }

    /// Every static `fl.c` under `value`, depth first.
    private static func fillColours(_ value: Any) -> [[Double]] {
        if let object = value as? [String: Any] {
            if object["ty"] as? String == "fl", let c = (object["c"] as? [String: Any])?["k"] as? [NSNumber] {
                return [c.map(\.doubleValue)]
            }
            return object.values.flatMap(fillColours)
        }
        return (value as? [Any])?.flatMap(fillColours) ?? []
    }

    private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}
