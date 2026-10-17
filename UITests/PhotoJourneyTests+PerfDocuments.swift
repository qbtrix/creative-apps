// PhotoJourneyTests+PerfDocuments.swift: photo-documents' perf journey PJ-P3
// (docs/blueprints/photo/features/photo-documents.md, Journey steps 6;
// blueprint photo 7.1, PB-19). `-PhotoFixture large` runs on fakes whose
// archive writes no file, so the test writes a 4000 x 3000 beach.png
// (writeTestPhoto), adds two layers in the UI, saves it as a Photo Document
// into `-PhotoSaveTo`'s folder (Keep layers?: Save as Photo Document), quits
// cleanly and relaunches on the saved beach.ora.
//
// Report-only (QB-L9, QB-L12; docs/review-rubric.md, How gates are set), as
// PhotoJourneyTests+Perf.swift: from the relaunch until the 4000 × 3000 header
// shows, the test polls the window and counts the polls that find the
// "Opening…" note (`photo.file.opening`, shown once an open has run 100 ms),
// and times each poll's round trip. A poll needs the app's main thread to
// answer the accessibility query, so a long round trip is a coarse sign of a
// main-thread stall; SuiteUI's FrameProbe (#330) isn't published by Photo's
// window yet, so there is no probe mark. The lines go to
// .build/ui-screens/photo-perf-open-document.txt and attach as
// "perf-report-open-document", after a "Saving…" line (`photo.file.saving`,
// polled from the Save as Photo Document click until the bar reads Saved,
// PB-18); the test asserts only that the document opens
// with its 3 layers, and says why when no "Opening…" sample was seen.
// Shots are "perf-documents-"; the ones that show the Keep layers? dialog or the
// beach.ora name are screen shots, which skip the audit.
import XCTest

final class PhotoPerfDocumentsJourneyTests: XCTestCase {
    /// A poll round trip over this many milliseconds counts as a stall (about six 60 Hz refreshes).
    static let stallMilliseconds = 100.0

    /// PJ-P3: save a 4000 x 3000, 3-layer document, reopen it; report "Opening…" and stalls.
    @MainActor func testOpenLargeDocument() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-perf-documents-\(UUID().uuidString)")
        let saves = folder.appending(path: "saves"), recovery = folder.appending(path: "recovery")
        try FileManager.default.createDirectory(at: saves, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "beach.png")
        try writeTestPhoto(to: file, width: 4000, height: 3000)

        // Open the large photo and add two layers.
        var photo = Journey("Photo", self, arguments: photoArguments(open: file, saveTo: saves, recoveryDir: recovery))
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 60), "the 4000 x 3000 beach.png didn't open")
        expectHeader("4000 × 3000 px", photo, timeout: 60, "beach.png isn't 4000 × 3000 px")
        photo.shot("perf-documents-opened")
        for _ in 0..<2 { photo.press(character: "n", [.command, .shift]) }
        expectHeader("3 layers", photo, timeout: 10, "two Shift-Command-N didn't make 3 layers")
        photo.shot("perf-documents-layers")

        // Save: Keep layers?, Save as Photo Document writes beach.ora into -PhotoSaveTo's folder.
        photo.press(character: "s", .command)
        // On the window's Keep layers? sheet, not its Touch Bar copy of the default button.
        let keep = photo.app.sheets.buttons["photo.file.keep-layers.document"].firstMatch
        XCTAssert(keep.waitForExistence(timeout: 10), "Save on a layered PNG didn't ask Keep layers?")
        photo.shot("perf-documents-keep-layers", screen: true)
        keep.click()
        let clicked = Date()
        let document = saves.appending(path: "beach.ora")
        let saved = photo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'photo.bar.saved' AND label == 'Saved'")).firstMatch
        // Report-only (PB-18): poll for "Saving…" (`photo.file.saving`, shown once a save has run 100 ms)
        // until the title bar's subtitle reads Saved, as the reopen loop below polls "Opening…".
        let savingNote = photo.element("photo.file.saving")
        var (savePolls, saveSeen, saveFirstSeen, isSaved) = (0, 0, Double?.none, false)
        while !isSaved, Date().timeIntervalSince(clicked) < 60 {
            let started = Date()
            if savingNote.exists {
                saveSeen += 1
                saveFirstSeen = saveFirstSeen ?? started.timeIntervalSince(clicked) * 1000
            }
            isSaved = saved.exists
            savePolls += 1
        }
        let saveSeconds = Date().timeIntervalSince(clicked)
        XCTAssert(isSaved, "Save as Photo Document never read Saved")
        let head = (try? Data(contentsOf: document).prefix(2)).map(Array.init) ?? []
        XCTAssertEqual(head, [0x50, 0x4B], "the saved beach.ora isn't a zip")
        photo.shot("perf-documents-saved", screen: true)

        // Quit cleanly (nothing unsaved, so no prompt), then relaunch on beach.ora.
        photo.press(character: "q", .command)
        if !photo.app.wait(for: .notRunning, timeout: 15) { photo.app.terminate() }
        photo = Journey("Photo", self, arguments: photoArguments(open: document, recoveryDir: recovery))
        let launched = Date()
        let note = photo.element("photo.file.opening")
        let opened = photo.app.descendants(matching: .any).matching(
            NSPredicate(format: "label CONTAINS %@", "4000 × 3000 px")).firstMatch
        var (polls, seen, firstSeen, longest, stalls) = (0, 0, Double?.none, 0.0, 0)
        var done = false
        while !done, Date().timeIntervalSince(launched) < 120 {
            let started = Date()
            if note.exists {
                seen += 1
                firstSeen = firstSeen ?? started.timeIntervalSince(launched) * 1000
            }
            done = opened.exists
            let trip = Date().timeIntervalSince(started) * 1000
            polls += 1
            longest = max(longest, trip)
            if trip > Self.stallMilliseconds { stalls += 1 }
        }
        let seconds = Date().timeIntervalSince(launched)
        XCTAssert(done, "beach.ora didn't reopen within 120 s")
        expectHeader("3 layers", photo, timeout: 5, "the reopened beach.ora doesn't have 3 layers")
        photo.shot("perf-documents-reopened", screen: true)

        let why = seen > 0
            ? "photo.file.opening seen in \(seen) of \(polls) polls"
            : "photo.file.opening never seen in \(polls) polls: the open finished before a poll found the note, "
                + "or it ran under 100 ms, so the note never showed"
        let saveWhy = saveSeen > 0
            ? "photo.file.saving seen in \(saveSeen) of \(savePolls) polls"
            : "photo.file.saving never seen in \(savePolls) polls: the save finished before a poll found the note, "
                + "or it ran under 100 ms, so the note never showed"
        report([
            "QB-L9 PJ-P3 saving: samples=\(saveSeen) "
                + "first-seen-ms=\(saveFirstSeen.map { String(format: "%.0f", $0) } ?? "n/a") "
                + "save-s=\(String(format: "%.2f", saveSeconds)) report-only (\(saveWhy); counted from the "
                + "Save as Photo Document click, no probe mark until FrameProbe #330 is wired)",
            "QB-L9 PJ-P3 opening: samples=\(seen) first-seen-ms=\(firstSeen.map { String(format: "%.0f", $0) } ?? "n/a") "
                + "open-s=\(String(format: "%.2f", seconds)) report-only (\(why); counted from launch() returning, "
                + "no probe mark until FrameProbe #330 is wired)",
            "QB-L12 PJ-P3 main-thread: polls=\(polls) longest-ms=\(String(format: "%.0f", longest)) "
                + "over-\(Int(Self.stallMilliseconds))ms=\(stalls) report-only (accessibility query round trips, "
                + "a coarse stand-in until FrameProbe #330)",
        ])
    }

    // MARK: - Steps

    /// Waits for a label holding `text`, as the header's "beach.png, 4000 × 3000 px, sRGB · 3 layers".
    @MainActor private func expectHeader(_ text: String, _ photo: Journey, timeout: TimeInterval, _ message: String) {
        let matching = photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text))
        if matching.firstMatch.waitForExistence(timeout: timeout) { return }
        let header = photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", " px, sRGB"))
            .firstMatch
        XCTFail("\(message) (no label holds \(text); the header reads \(header.exists ? header.label : "nothing"))")
    }

    /// Prints the report-only lines, writes them for the contact sheet and attaches them.
    @MainActor private func report(_ lines: [String]) {
        for line in lines { print(line) }
        // This file is UITests/PhotoJourneyTests+PerfDocuments.swift, so its grandparent is the repo root.
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let folder = root.appending(path: ".build/ui-screens")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? Data((lines.joined(separator: "\n") + "\n").utf8).write(to: folder.appending(path: "photo-perf-open-document.txt"))
        if let json = try? JSONEncoder().encode(lines) {
            let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
            attachment.name = "perf-report-open-document"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
