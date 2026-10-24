// SuiteJourneyTests+Unsaved.swift: SJ-UP, RJ-X48's check (adopt-kernel-unsaved-prompt UP-2;
// docs/blueprints/suiteui/features/adopt-kernel-unsaved-prompt.md, Journey steps). In each of Design, Photo,
// Flare and Halo it makes one edit and presses ⌘W: the sheet reads UnsavedPrompt's message for the document
// with Save, Don't Save and Cancel (`<app>.close.save|dontSave|cancel`, from UnsavedPrompt.answers); Escape
// cancels and the window stays, still dirty; ⌘W again and ⌘D (Don't Save) closes it. Then a fresh launch, an
// edit and File > New (Open… in Halo, which has no New that replaces the project) ask the same; Save on the untitled document opens the Save panel, and cancelling the
// panel (a sheet, or the app-modal dialog Design's runs) keeps the document. Every leg runs; none skips (UP-14).
// The bundle doesn't link SuiteKernel, so the words below mirror UnsavedPrompt (Sources/SuiteKernel/Session/
// DocumentSession.swift) and must change with it.
import XCTest

final class SuiteUnsavedJourneyTests: XCTestCase {
    /// One editor's leg: how to launch it on a new document, its id prefix, the document's name and one edit.
    private struct Editor {
        let app: String
        let prefix: String
        let name: String
        let arguments: [String]
        /// File's item that replaces the document ("New File" in Design, "Open…" in Halo, "New" elsewhere).
        var newItem = "New"
        /// The canvas's id ("halo.viewer" in Halo, which draws no `suite.canvas`).
        var canvas = "suite.canvas"
        let edit: @MainActor (Journey) -> Void
    }

    /// UnsavedPrompt.message(for:).
    private static func message(for name: String) -> String {
        "Do you want to save the changes made to the document \u{201C}\(name)\u{201D}?"
    }

    /// UnsavedPrompt.answers in order, with UnsavedPrompt.title(of:) for each.
    private static let answers = [("save", "Save"), ("dontSave", "Don't Save"), ("cancel", "Cancel")]

    /// SJ-UP: every editor asks the same question the same way before it closes or replaces a dirty document.
    @MainActor func testEveryEditorAsksBeforeClosing() {
        for leg in Leg.allCases { run(leg) }
    }

    // MARK: - Legs

    /// The legs in order, by case rather than as function values (a method reference held as a
    /// `@MainActor` function is implicitly Sendable, and XCTestCase isn't).
    private enum Leg: CaseIterable { case design, photo, flare, halo }

    @MainActor private func run(_ leg: Leg) {
        switch leg {
        case .design: designLeg()
        case .photo: photoLeg()
        case .flare: flareLeg()
        case .halo: haloLeg()
        }
    }

    @MainActor private func designLeg() {
        askBeforeClosing(Editor(
            app: "Design", prefix: "design", name: "Untitled",
            arguments: ["-DesignServices", "live", "-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"],
            newItem: "New File",
            edit: { design in
                design.element("suite.tools").buttons["Rectangle"].click()
                design.drag(on: "suite.canvas", from: CGVector(dx: 0.56, dy: 0.61), to: CGVector(dx: 0.70, dy: 0.75))
            }))
    }

    @MainActor private func photoLeg() {
        let recovery = FileManager.default.temporaryDirectory.appending(path: "photo-unsaved-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: recovery) }
        askBeforeClosing(Editor(
            app: "Photo", prefix: "photo", name: "Untitled",
            arguments: ["-PhotoFixture", "sample", "-PhotoRecoveryDir", recovery.path],
            edit: { photo in
                photo.element("suite.tools").buttons["Brush"].click()
                photo.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.3), to: CGVector(dx: 0.8, dy: 0.7))
            }))
    }

    @MainActor private func flareLeg() {
        askBeforeClosing(Editor(
            app: "Flare", prefix: "flare", name: "Untitled", arguments: ["-FlareFixture", "bounce"],
            edit: { flare in flare.element("suite.sidebar").buttons["New Layer"].click() }))
    }

    @MainActor private func haloLeg() {
        askBeforeClosing(Editor(
            app: "Halo", prefix: "halo", name: "Untitled", arguments: ["-HaloSample", "two-comps"],
            newItem: "Open\u{2026}", canvas: "halo.viewer",
            edit: { halo in
                halo.element("halo.composition.new").click()
                halo.click("Create", in: .sheet)
            }))
    }

    // MARK: - Steps

    /// Steps 1 to 4 of SJ-UP on `editor`.
    @MainActor private func askBeforeClosing(_ editor: Editor) {
        var journey = launch(editor)
        let window = journey.app.windows.firstMatch
        editor.edit(journey)

        // 1. ⌘W: the sheet names the document, with Save, Don't Save and Cancel.
        journey.press(character: "w", .command)
        expectPrompt(editor, journey)
        journey.shot("unsaved-sheet")

        // 2. Escape cancels: the window stays, and ⌘W still asks (still dirty).
        journey.press(.escape)
        XCTAssert(sheet(journey).waitForNonExistence(timeout: 5), "\(editor.app): Escape left the sheet up")
        XCTAssert(window.exists, "\(editor.app): Cancel closed the window")

        // 3. ⌘W again, ⌘D (Don't Save): the window closes.
        journey.press(character: "w", .command)
        expectPrompt(editor, journey)
        journey.press(character: "d", .command)
        XCTAssert(window.waitForNonExistence(timeout: 10), "\(editor.app): Don't Save left the window open")
        journey.app.terminate()

        // 4. A new edit, File > New: the same sheet; Save on the untitled document opens the Save panel,
        // and cancelling the panel keeps the document.
        journey = launch(editor)
        editor.edit(journey)
        journey.app.menuBars.menuBarItems["File"].click()
        journey.app.menuBars.menuItems[editor.newItem].firstMatch.click()
        expectPrompt(editor, journey)
        let saveButton = sheet(journey).buttons["\(editor.prefix).close.save"]
        saveButton.click()
        XCTAssert(saveButton.waitForNonExistence(timeout: 5), "\(editor.app): Save left the unsaved sheet up")
        XCTAssert(savePanel(journey).exists, "\(editor.app): Save on Untitled opened no Save panel")
        // The Save panel is the system's: its title-bar text fails the contrast check on the runner (#4231),
        // so the shot skips the audit, as for another app's element (Journey.shot(_:element:audit:)).
        journey.shot("unsaved-save-panel", element: journey.app.windows.firstMatch, audit: false)
        journey.press(.escape)
        XCTAssert(journey.app.windows.firstMatch.waitForExistence(timeout: 5), "\(editor.app): cancelling the panel closed the document")
        XCTAssert(journey.element(editor.canvas).exists, "\(editor.app): cancelling the panel replaced the document")
        journey.app.terminate()
    }

    /// Launches `editor` on its new document and waits for its canvas.
    @MainActor private func launch(_ editor: Editor) -> Journey {
        let journey = Journey(editor.app, self, arguments: editor.arguments)
        XCTAssert(journey.app.windows.firstMatch.waitForExistence(timeout: 30), "\(editor.app): no window opened")
        XCTAssert(journey.element(editor.canvas).waitForExistence(timeout: 10), "\(editor.app): no canvas (\(editor.canvas))")
        return journey
    }

    /// The window's sheet.
    @MainActor private func sheet(_ journey: Journey) -> XCUIElement { journey.app.sheets.firstMatch }

    /// The Save panel: a sheet on the window, else an app-modal dialog.
    @MainActor private func savePanel(_ journey: Journey) -> XCUIElement {
        let sheet = sheet(journey)
        if sheet.waitForExistence(timeout: 10) { return sheet }
        let dialog = journey.app.dialogs.firstMatch
        _ = dialog.waitForExistence(timeout: 2)
        return dialog
    }

    /// The sheet is up and matches UnsavedPrompt: its message for `editor.name`, then each answer's button by id and title.
    @MainActor private func expectPrompt(_ editor: Editor, _ journey: Journey) {
        let sheet = sheet(journey)
        XCTAssert(sheet.waitForExistence(timeout: 5), "\(editor.app): no unsaved-changes sheet")
        let message = Self.message(for: editor.name)
        let text = sheet.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", message, message)).firstMatch
        XCTAssert(text.waitForExistence(timeout: 5), "\(editor.app): the sheet doesn't read \(message)")
        for (answer, title) in Self.answers {
            let button = sheet.buttons["\(editor.prefix).close.\(answer)"]
            XCTAssert(button.exists, "\(editor.app): the sheet has no \(editor.prefix).close.\(answer)")
            XCTAssertEqual(button.title, title, "\(editor.app): \(answer) reads another title")
        }
    }
}
