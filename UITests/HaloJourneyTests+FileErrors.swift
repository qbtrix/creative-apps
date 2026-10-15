// HaloJourneyTests+FileErrors.swift: H-J11, opening bad files (history-files,
// HF-12; docs/blueprints/halo/features/history-files.md, Journey steps 3).
// No fixture: the test writes four files into its own temp folder (not
// JSON, a format 2 envelope, a format 1 project whose composition is only
// an id, and 64 MiB + 1 byte of spaces) and launches Halo once per file with
// `-HaloOpenFile <absolute path>`. Each open ends in one system alert whose
// title is the Model's message; after OK the "No Composition" empty state
// stays. One shot per file with its alert up, `halo-file-errors-<n>`, and
// one after OK, `halo-file-errors-<n>-ok`.
import XCTest

final class HaloFileErrorsJourneyTests: XCTestCase {
    /// H-J11: four bad files, four alerts, the project left as it was.
    @MainActor func testOpenBadFiles() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "halo-file-errors-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let damaged = "This project is damaged: "
        let cases: [(file: String, data: Data, message: String)] = [
            ("NotJSON.halo", Data("not json".utf8), "This file isn't a Halo project."),
            ("Newer.halo", Data(#"{"format":"halo","version":2}"#.utf8),
             "This project was saved by a newer Halo (format 2). Update Halo to open it."),
            ("Damaged.halo", Data(#"{"format":"halo","version":1,"project":{"compositions":[{"id":"a"}]}}"#.utf8), damaged),
            ("Large.halo", Data(repeating: 0x20, count: 64 * 1024 * 1024 + 1),
             "This project is larger than Halo can open (64 MB)."),
        ]
        for (index, item) in cases.enumerated() {
            let path = folder.appending(path: item.file).path
            try item.data.write(to: URL(fileURLWithPath: path))
            let halo = Journey("Halo", self, arguments: ["-HaloOpenFile", path, "-HaloWindowSize", "1280x800"])
            XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened for \(item.file)")
            let step = "file-errors-\(index + 1)"

            let sheet = halo.app.sheets.firstMatch
            let alert = sheet.waitForExistence(timeout: 30) ? sheet : halo.app.dialogs.firstMatch
            XCTAssert(alert.waitForExistence(timeout: 5), "opening \(item.file) showed no alert")
            let title = alertTitle(startingWith: item.message, in: alert)
            XCTAssert(title.waitForExistence(timeout: 5), "the \(item.file) alert doesn't read \(item.message)")
            if item.message == damaged {
                let reason = text(of: title).dropFirst(damaged.count).trimmingCharacters(in: .punctuationCharacters)
                XCTAssertFalse(reason.isEmpty, "the damaged alert gives no reason: \(text(of: title))")
            } else {
                XCTAssertEqual(text(of: title), item.message, "the \(item.file) alert's title")
            }
            halo.shot(step)

            alert.buttons["OK"].click()
            XCTAssert(
                emptyState(in: halo).waitForExistence(timeout: 5), "No Composition didn't stay after \(item.file)")
            XCTAssertEqual(halo.element("halo.file").value as? String, "Untitled", "a failed open changed the file")
            halo.shot("\(step)-ok")
            halo.app.terminate()
        }
    }

    /// The static text in `alert` whose label or value starts with `prefix`.
    @MainActor private func alertTitle(startingWith prefix: String, in alert: XCUIElement) -> XCUIElement {
        alert.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", prefix, prefix))
            .firstMatch
    }

    /// A static text's string: its label, else its value.
    @MainActor private func text(of element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }

    /// The viewer's "No Composition" title.
    @MainActor private func emptyState(in halo: Journey) -> XCUIElement {
        halo.app.splitGroups.firstMatch.staticTexts.matching(
            NSPredicate(format: "label == %@ OR value == %@", "No Composition", "No Composition")).firstMatch
    }
}
