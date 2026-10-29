// DesignJourneyTests+BadFiles.swift: J16, opening bad files (files-history,
// FH-6; docs/blueprints/design/features/files-history.md, Journey 3). No
// fixture: the test writes four files into its own temp folder (not JSON, a
// version 99 file, a file with no pages, and one that uses the id node-2
// twice) and launches Design once per file with `-DesignOpenFile <path>`.
// Each open ends in one system alert (DesignFileProblem) titled
// "<file> can't be opened." whose message is the reason word for word from
// DesignFileError, so no empty text field trips the contrast audit (#3052); after OK the window stays empty (the New File empty
// state, no canvas). Live services only: FakeFiling has no version check, so
// a fake-mode run skips. One shot per file with its alert up,
// `design-bad-files-<n>`, and one after OK, `design-bad-files-<n>-ok`.
import XCTest

final class DesignBadFilesJourneyTests: XCTestCase {
    /// The services this journey runs on; `-DesignServices fake` would open on FakeFiling.
    private static let services = "live"

    /// A rectangle layer with `id`, in the file format's own keys (DesignFilingTests' node).
    private static func node(_ id: String) -> String {
        #"{"children":[],"cornerRadius":0,"fill":{"blue":217,"green":217,"red":217},"frame":{"height":80,"width":100,"x":100,"y":100},"id":""#
            + id + #"","isHidden":false,"isLocked":false,"kind":"rectangle","name":"A","opacity":1,"text":"","textStyle":{"alignment":"leading","family":"System","size":16,"weight":400}}"#
    }

    /// The four bad files, each with the reason its alert must read.
    private static let badFiles: [(file: String, data: Data, reason: String)] = [
        ("NotJSON.design", Data("This is not JSON.".utf8), "It is not a Design file."),
        ("Newer.design", Data(#"{"pages":[],"version":99}"#.utf8),
         "It was made by a newer version of Design (file version 99; this version opens up to 2)."
            + " Update Design to open it."),
        ("NoPages.design", Data(#"{"pages":[],"version":1}"#.utf8), "It has no pages."),
        ("DuplicateID.design", Data((#"{"pages":[{"frameHeight":100,"frameWidth":100,"id":"page-1","name":"Page 1","nodes":["#
            + node("node-2") + "," + node("node-2") + #"]}],"version":1}"#).utf8),
         "It is damaged: two of its layers share the id node-2."),
    ]

    /// J16: four bad files, four alerts in words, the window left empty.
    @MainActor func testOpenBadFiles() throws {
        try walkBadFiles(services: Self.services)
    }

    @MainActor private func walkBadFiles(services: String) throws {
        if services == "fake" {
            throw XCTSkip("J16 runs on live services only: FakeFiling has no version check")
        }
        let folder = FileManager.default.temporaryDirectory.appending(path: "design-bad-files-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        for (index, item) in Self.badFiles.enumerated() {
            let path = folder.appending(path: item.file).path
            try item.data.write(to: URL(fileURLWithPath: path))
            let design = Journey("Design", self, arguments: ["-DesignServices", services, "-DesignOpenFile", path])
            XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened for \(item.file)")
            let step = "bad-files-\(index + 1)"

            let sheet = design.app.sheets.firstMatch
            let alert = sheet.waitForExistence(timeout: 30) ? sheet : design.app.dialogs.firstMatch
            XCTAssert(alert.waitForExistence(timeout: 5), "opening \(item.file) showed no alert")
            let title = alert.staticTexts.matching(
                NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", item.file, item.file)).firstMatch
            XCTAssert(title.waitForExistence(timeout: 5), "the \(item.file) alert doesn't name the file")
            XCTAssertEqual(text(of: title), "\(item.file) can't be opened.", "the \(item.file) alert's title")
            let message = alert.staticTexts.matching(
                NSPredicate(format: "label == %@ OR value == %@", item.reason, item.reason)).firstMatch
            XCTAssert(message.waitForExistence(timeout: 5), "the \(item.file) alert's message isn't the reason")
            design.shot(step)

            alert.buttons["OK"].click()
            XCTAssert(design.element("design.new-file").waitForExistence(timeout: 5),
                      "the window didn't stay empty after \(item.file) (no design.new-file)")
            XCTAssertFalse(design.element("suite.canvas").exists, "the window holds a document after refusing \(item.file)")
            XCTAssertEqual(design.app.windows.firstMatch.title, "Design", "a refused open named the window after \(item.file)")
            design.shot("\(step)-ok")
            design.app.terminate()
        }
    }

    /// A static text's string: its label, else its value.
    @MainActor private func text(of element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }
}
