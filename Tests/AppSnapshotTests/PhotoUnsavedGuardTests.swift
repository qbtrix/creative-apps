// PhotoUnsavedGuardTests.swift (adopt-kernel-unsaved-prompt UP-7, on since UP-8): the hooks a Photo window hands
// SuiteUI's `.unsavedChangesGuard` (PhotoWindowEditedView.unsavedHooks) and Quit's walk over the dirty windows
// (PhotoUnsavedFlow.quit). The buttons are `photo.close.*`; the name is the image's ("Untitled" before its first
// save, nil with no image); the dirty state is the workspace's. Quit asks each dirty window in turn through
// `UnsavedGuard.proceed`, autosaved first; Cancel or a failed save keeps the app and every autosave, and Don't Save
// drops a window's autosave only once every window answered. Answers are injected (`UnsavedHooks.ask`), so no
// sheet runs. macOS only.
#if canImport(AppKit)
import AppKit
import CoreRaster
import PhotoModel
import SuiteKernel
import Testing

@testable import PhotoApp
@testable import SuiteUI

@MainActor private final class Log { var events: [String] = [] }

/// A window that answers `answer` through the guard and logs what Quit asked of it.
@MainActor private final class FakeWindow: PhotoUnsavedWindow {
    let name: String, answer: UnsavedPrompt.Answer, saves: Bool, log: Log
    var isDirty: Bool
    var window: NSWindow? { nil }

    init(_ name: String, dirty: Bool, answer: UnsavedPrompt.Answer = .cancel, saves: Bool = true, log: Log) {
        self.name = name
        isDirty = dirty
        self.answer = answer
        self.saves = saves
        self.log = log
    }

    var unsavedHooks: UnsavedHooks {
        var hooks = UnsavedHooks(
            idPrefix: "photo", documentName: { self.name }, isDirty: { self.isDirty },
            save: {
                self.log.events.append("save \(self.name)")
                if self.saves { self.isDirty = false }
                return self.saves
            })
        hooks.ask = { _, _, _ in
            self.log.events.append("ask \(self.name)")
            return self.answer
        }
        return hooks
    }

    func prepareToQuit() async { log.events.append("autosave \(name)") }
    func discardChanges() { log.events.append("discard \(name)") }
}

@MainActor
@Suite struct PhotoUnsavedGuardTests {
    /// A 4 x 3 white "beach.png", opened clean, with a layer added when `edited`.
    private func beach(edited: Bool) throws -> PhotoWorkspace {
        let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.openImage(try ImageIOCodec().encode(white, as: .png, quality: 1), name: "beach.png", codec: ImageIOCodec())
        if edited { workspace.addLayer() }
        return workspace
    }

    private func hooks(_ model: PhotoWorkspace?) -> UnsavedHooks {
        PhotoWindowEditedView.unsavedHooks(model: { model }, files: nil, perform: nil)
    }

    @Test func buttonsArePhotosCloseIDs() {
        let hooks = hooks(nil)
        #expect(hooks.idPrefix == "photo")
        #expect(UnsavedGuard.identifier(.save, prefix: hooks.idPrefix) == "photo.close.save")
        #expect(UnsavedGuard.identifier(.dontSave, prefix: hooks.idPrefix) == "photo.close.dontSave")
        #expect(UnsavedGuard.identifier(.cancel, prefix: hooks.idPrefix) == "photo.close.cancel")
    }

    @Test func nameIsTheImages() throws {
        #expect(hooks(nil).documentName() == nil, "no workspace still named a document")
        #expect(hooks(PhotoWorkspace()).documentName() == nil, "an empty window still named a document")
        #expect(hooks(try beach(edited: true)).documentName() == "beach.png")
        var untitled = PhotoWorkspace(services: .fake)
        try untitled.newCanvas(width: 4, height: 3)
        #expect(hooks(untitled).documentName() == "Untitled")
    }

    @Test func dirtyIsTheWorkspaces() throws {
        #expect(!hooks(try beach(edited: false)).isDirty(), "the image as opened read dirty")
        #expect(hooks(try beach(edited: true)).isDirty())
        #expect(!hooks(nil).isDirty())
    }

    @Test func saveWithNoWindowDoesNotLand() async {
        #expect(!(await hooks(nil).save()), "a Save with no file session let the window go")
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
