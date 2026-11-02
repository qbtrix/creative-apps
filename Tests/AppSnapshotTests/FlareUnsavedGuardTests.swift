// FlareUnsavedGuardTests.swift (adopt-kernel-unsaved-prompt UP-9, on since UP-10): the hooks a Flare window
// hands SuiteUI's `.unsavedChangesGuard` and `UnsavedGuard.proceed` (FlareWindow.unsavedHooks). Their buttons are
// `flare.close.*`; the name is the open animation's title ("Untitled" before its first save, nil with nothing
// open); the dirty state is the workspace's DocumentSession; and Save runs File > Save, landing only when the write
// landed and the workspace then reads clean, so a cancelled Save panel or a failed write keeps the animation. Open
// and New ask first: Cancel stops them and the dirty animation stays, Don't Save lets them replace it. The sheet is
// a fake answerer (`UnsavedHooks.ask`), so no window server is needed. macOS only.
#if canImport(AppKit)
import AppKit
import FlareCore
import FlareModel
import Foundation
import SuiteKernel
import Testing

@testable import FlareApp
@testable import SuiteUI

/// The window's workspace, the saves its File > Save ran and the questions the fake sheet was asked.
@MainActor private final class FlareBox {
    var model = FlareWorkspace(services: .fake())
    var saves = 0
    /// What File > Save does here: writes (marks the workspace saved as this file name) or, with nil, lands nothing.
    var saveAs: String? = "Bounce.flare"
    /// Each question the fake sheet was asked, as "<prefix>: <name>".
    var asked: [String] = []

    var hooks: UnsavedHooks {
        FlareWindow.unsavedHooks(model: { self.model }) {
            self.saves += 1
            guard let name = self.saveAs, let save = self.model.saveData() else { return false }
            self.model.didSave(save, named: name)
            return true
        }
    }

    /// The hooks with the sheet swapped for one that records the question and answers `answer`.
    func hooks(answering answer: UnsavedPrompt.Answer) -> UnsavedHooks {
        var hooks = hooks
        hooks.ask = { name, prefix, _ in
            self.asked.append("\(prefix): \(name)")
            return answer
        }
        return hooks
    }

    /// What Open or New does once the guard lets it go on: the Button sample replaces the animation.
    func replace() throws {
        let button = try #require(FlareFixtures.named("button"))
        model.finishOpen(.success(button), named: "Button.flare")
    }

    /// The bounce fixture as `-FlareFixture bounce` opens it (untitled, clean), with one layer added when `edited`.
    static func bounce(edited: Bool) -> FlareBox {
        let box = FlareBox()
        box.model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        #expect(box.model.document != nil, "the bounce fixture didn't open")
        if edited { box.model.addLayer() }
        return box
    }
}

@MainActor
@Suite struct FlareUnsavedGuardTests {
    @Test func buttonsAreFlaresCloseIDs() {
        let hooks = FlareBox().hooks
        #expect(hooks.idPrefix == "flare")
        #expect(UnsavedGuard.identifier(.save, prefix: hooks.idPrefix) == "flare.close.save")
        #expect(UnsavedGuard.identifier(.dontSave, prefix: hooks.idPrefix) == "flare.close.dontSave")
        #expect(UnsavedGuard.identifier(.cancel, prefix: hooks.idPrefix) == "flare.close.cancel")
    }

    @Test func nameIsTheOpenAnimations() throws {
        #expect(FlareBox().hooks.documentName() == nil, "nothing open still named a document")
        let box = FlareBox.bounce(edited: true)
        #expect(box.hooks.documentName() == "Untitled")
        let save = try #require(box.model.saveData())
        box.model.didSave(save, named: "Bounce.flare")
        #expect(box.hooks.documentName() == box.model.title)
        #expect(box.hooks.documentName() == "Bounce")
    }

    @Test func dirtyIsTheDocumentSession() {
        let clean = FlareBox.bounce(edited: false)
        #expect(!clean.hooks.isDirty(), "the fixture as opened read dirty")
        let edited = FlareBox.bounce(edited: true)
        #expect(edited.hooks.isDirty())
        #expect(edited.hooks.isDirty() == edited.model.isDirty)
        edited.model.undo()
        #expect(!edited.hooks.isDirty(), "undoing back to the open read dirty")
    }

    @Test func saveRunsFileSaveAndLandsWhenClean() async {
        let box = FlareBox.bounce(edited: true)
        let landed = await box.hooks.save()
        #expect(box.saves == 1, "Save ran File > Save \(box.saves) times")
        #expect(landed && !box.model.isDirty)
    }

    @Test func cancelledSaveDoesNotLand() async {
        let box = FlareBox.bounce(edited: true)
        box.saveAs = nil
        let landed = await box.hooks.save()
        #expect(box.saves == 1)
        #expect(!landed, "a Save that wrote nothing let the animation go")
        #expect(box.model.isDirty)
    }

    @Test func saveThatLeavesItDirtyDoesNotLand() async {
        let box = FlareBox.bounce(edited: true)
        let hooks = FlareWindow.unsavedHooks(model: { box.model }) { true }
        let landed = await hooks.save()
        #expect(!landed, "a save that reported success over a dirty animation landed")
        #expect(box.model.isDirty)
    }

    @Test func cleanOpenGoesOnUnasked() async throws {
        let box = FlareBox.bounce(edited: false)
        if await UnsavedGuard.proceed(box.hooks(answering: .cancel), in: nil) { try box.replace() }
        #expect(box.asked.isEmpty, "a clean animation asked")
        #expect(box.model.title == "Button", "a clean animation stopped Open")
    }

    @Test func cancelKeepsTheDirtyAnimation() async throws {
        let box = FlareBox.bounce(edited: true)
        let before = box.model.document
        if await UnsavedGuard.proceed(box.hooks(answering: .cancel), in: nil) { try box.replace() }
        #expect(box.asked == ["flare: Untitled"])
        #expect(box.model.document == before, "Cancel let Open or New replace the dirty animation")
        #expect(box.model.isDirty && box.saves == 0)
    }

    @Test func dontSaveLetsOpenAndNewGoOn() async throws {
        let box = FlareBox.bounce(edited: true)
        if await UnsavedGuard.proceed(box.hooks(answering: .dontSave), in: nil) { try box.replace() }
        #expect(box.asked == ["flare: Untitled"])
        #expect(box.model.title == "Button" && !box.model.isDirty, "Don't Save didn't let Open or New go on")
        #expect(box.saves == 0)
    }

    @Test func saveThatFailsStopsOpenAndNew() async throws {
        let box = FlareBox.bounce(edited: true)
        box.saveAs = nil
        let before = box.model.document
        if await UnsavedGuard.proceed(box.hooks(answering: .save), in: nil) { try box.replace() }
        #expect(box.saves == 1)
        #expect(box.model.document == before, "a failed save let Open or New replace the animation")
    }
}
#endif
