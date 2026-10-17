// FlareJourneyTests+OpenErrors.swift: J27 (layers-files LF-4, F17b;
// docs/blueprints/flare.md, section 3.3). The test writes four bad files into
// its own temp folder and launches Flare on each with `-FlareOpenFile`, the
// way Open Recent opens a file: `not json`, a newer format
// (`{"format":"flare","version":2}`), a JSON object that isn't a Flare file
// (`{"a":1}`) and 65 MB of spaces, over the 64 MB limit. Each shows the system
// alert with section 3.3's text; OK closes it and the empty state ("No
// Animation Open") stays. The large file reads for a while first, so its
// progress row (`flare.open.progress`) is shot when it shows; whether it shows
// within 100 ms is FlareLoadProgressTests' and P7's to prove, not a journey's.
// One shot per file, `flare-open-error-<n>`.
import XCTest

final class FlareOpenErrorJourneys: XCTestCase {
    @MainActor func testOpenBadFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-open-errors-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }

        let notFlare = "This file isn't a Flare animation."
        let cases: [(name: String, bytes: Data, message: String)] = [
            ("not-json.flare", Data("not json".utf8), notFlare),
            ("newer.flare", Data(#"{"format":"flare","version":2}"#.utf8),
             "This file was made by a newer Flare (format 2). Update Flare to open it."),
            ("other.flare", Data(#"{"a":1}"#.utf8), notFlare),
            ("large.flare", Data(repeating: 0x20, count: 65 * 1024 * 1024),
             "This file is larger than Flare can open (64 MB)."),
        ]
        for (index, bad) in cases.enumerated() {
            let file = folder.appending(path: bad.name)
            try bad.bytes.write(to: file)
            let step = "open-error-\(index + 1)"
            let flare = Journey("Flare", self, arguments: ["-FlareOpenFile", file.path])
            XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened for \(bad.name)")
            if bad.name == "large.flare", flare.element("flare.open.progress").waitForExistence(timeout: 2) {
                flare.shot("\(step)-progress")
            }
            let alert = openAlert(flare)
            let text = alert.staticTexts.matching(
                NSPredicate(format: "label == %@ OR value == %@", bad.message, bad.message)).firstMatch
            XCTAssert(text.waitForExistence(timeout: 20), "\(bad.name) showed no alert reading \"\(bad.message)\"")
            flare.shot(step, screen: true)
            alert.buttons["OK"].click()
            let empty = flare.app.staticTexts["No Animation Open"]
            XCTAssert(empty.waitForExistence(timeout: 10), "the empty state went away after \(bad.name)")
            XCTAssertFalse(flare.element("flare.open.progress").exists, "the progress row stayed after \(bad.name)")
            flare.shot("\(step)-empty")
            flare.app.terminate()
        }
    }

    /// The open failure's alert: a sheet on the window, else a dialog.
    @MainActor private func openAlert(_ flare: Journey) -> XCUIElement {
        let sheet = flare.app.sheets.firstMatch
        return sheet.waitForExistence(timeout: 20) ? sheet : flare.app.dialogs.firstMatch
    }
}
