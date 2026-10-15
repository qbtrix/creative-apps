// PhotoUnsavedPromptTests.swift: the unsaved-changes prompt on close and Quit
// (photo-documents D-10, PJ-2, PJ-3): the alert's text and buttons for
// "beach.png"; a clean window closes without asking; Quit asks each dirty
// window in turn, autosaved first; Cancel or a failed save keeps the app and
// every autosave. Windows and answers are injected, so no NSAlert runs. macOS only.
#if os(macOS)
import Testing

@testable import PhotoApp
@testable import PhotoModel

@MainActor private final class Log { var events: [String] = [] }

/// A window that answers `answer` and logs what the flow asked of it.
@MainActor private final class FakeWindow: PhotoUnsavedWindow {
    let name: String, answer: PhotoUnsavedPrompt.Answer, saves: Bool, log: Log
    var isDirty: Bool

    init(_ name: String, dirty: Bool, answer: PhotoUnsavedPrompt.Answer = .cancel, saves: Bool = true, log: Log) {
        self.name = name
        isDirty = dirty
        self.answer = answer
        self.saves = saves
        self.log = log
    }

    func prepareToQuit() async { log.events.append("autosave \(name)") }
    func ask() async -> PhotoUnsavedPrompt.Answer {
        log.events.append("ask \(name)")
        return answer
    }
    func save() async -> Bool {
        log.events.append("save \(name)")
        return saves
    }
    func discardChanges() { log.events.append("discard \(name)") }
}

@MainActor
@Suite struct PhotoUnsavedPromptTests {
    @Test func theAlertForBeachPNG() {
        #expect(PhotoUnsavedPrompt.message(for: "beach.png") == "Do you want to save the changes made to the document “beach.png”?")
        #expect(PhotoUnsavedPrompt.informativeText == "Your changes will be lost if you don't save them.")
        #expect(PhotoUnsavedPrompt.choices.map(\.title) == ["Save", "Don't Save", "Cancel"])
    }

    @Test func aCleanWindowClosesWithoutAsking() async {
        let log = Log()
        let clean = FakeWindow("clean", dirty: false, log: log)
        #expect(!PhotoUnsavedFlow.asksOnClose(clean))
        #expect(await PhotoUnsavedFlow.close(clean))
        #expect(log.events.isEmpty)
    }

    @Test func aDirtyWindowClosesOnSaveOrDontSaveAndStaysOnCancel() async {
        let log = Log()
        #expect(await PhotoUnsavedFlow.close(FakeWindow("a", dirty: true, answer: .save, log: log)))
        #expect(!(await PhotoUnsavedFlow.close(FakeWindow("b", dirty: true, answer: .save, saves: false, log: log))))
        #expect(await PhotoUnsavedFlow.close(FakeWindow("c", dirty: true, answer: .dontSave, log: log)))
        #expect(!(await PhotoUnsavedFlow.close(FakeWindow("d", dirty: true, answer: .cancel, log: log))))
        #expect(log.events == ["ask a", "save a", "ask b", "save b", "ask c", "discard c", "ask d"])
    }

    @Test func quitAsksEachDirtyWindowInTurn() async {
        let log = Log()
        let windows = [
            FakeWindow("one", dirty: true, answer: .save, log: log), FakeWindow("clean", dirty: false, log: log),
            FakeWindow("two", dirty: true, answer: .dontSave, log: log),
        ]
        #expect(await PhotoUnsavedFlow.quit(windows))
        #expect(log.events == ["autosave one", "ask one", "save one", "autosave two", "ask two", "discard two"])
    }

    @Test func cancelOrAFailedSaveStopsQuitAndKeepsEveryAutosave() async {
        let log = Log()
        let cancelled = [
            FakeWindow("one", dirty: true, answer: .dontSave, log: log), FakeWindow("two", dirty: true, log: log),
        ]
        #expect(!(await PhotoUnsavedFlow.quit(cancelled)))
        let failing = [
            FakeWindow("three", dirty: true, answer: .save, saves: false, log: log),
            FakeWindow("four", dirty: true, answer: .dontSave, log: log),
        ]
        #expect(!(await PhotoUnsavedFlow.quit(failing)))
        #expect(log.events == [
            "autosave one", "ask one", "autosave two", "ask two", "autosave three", "ask three", "save three",
        ])
    }
}
#endif
