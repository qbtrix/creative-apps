// HaloUnsavedGuardTests.swift (adopt-kernel-unsaved-prompt UP-11, on since UP-12): the hooks a Halo window
// hands SuiteUI's `.unsavedChangesGuard` and `UnsavedGuard.proceed` (HaloWindow.unsavedHooks). Their buttons
// are `halo.close.*`; the name is the project's ("Untitled" before its first save, nil with no composition
// and no file); the dirty state is the project's DocumentSession; and Save runs File > Save (`HaloCommand.save`
// through the window's perform), landing only when the project then reads clean, so a cancelled Save panel or
// a failed write keeps the window. With a fake answerer in place of the sheet, a dirty project asks before
// ⌘W closes it or Open replaces it and Cancel stops both; a clean one goes on unasked. The window wires the
// guard on its root and its Open through `proceed`, with its old SwiftUI alert gone. macOS only.
#if canImport(AppKit)
import AppKit
import Foundation
import SuiteKernel
import Testing

@testable import HaloApp
@testable import HaloModel
@testable import SuiteUI

/// The window's project, the commands its perform received and the questions the fake sheet was asked.
@MainActor private final class HaloBox {
    var model = HaloProject(services: .fake)
    var saves = 0
    /// What File > Save does here: writes (marks the project saved at `saveTo`) or, with nil, lands nothing
    /// (the Save panel an untitled project opens, then cancelled).
    var saveTo: String? = "/tmp/HaloUnsavedGuardTests/Spot.halo"
    /// The fake sheet's answer and what it was asked, as "<prefix>:<name>".
    var answer = UnsavedPrompt.Answer.cancel
    var asked: [String] = []

    var hooks: UnsavedHooks {
        var hooks = HaloWindow.unsavedHooks(model: { self.model }) { command in
            guard command == .save else { return }
            self.saves += 1
            if let path = self.saveTo { self.model.didSave(name: HaloProject.fileName(fromPath: path), path: path) }
        }
        hooks.ask = { name, prefix, _ in
            self.asked.append("\(prefix):\(name)")
            return self.answer
        }
        return hooks
    }

    /// The `two-comps` fixture, opened unsaved, with a third composition made when `edited`.
    static func twoComps(edited: Bool) throws -> HaloBox {
        let box = HaloBox()
        box.model = HaloProject(services: .fake, document: try #require(HaloFixtures.project("two-comps")))
        if edited { box.model.newComposition() }
        return box
    }
}

@MainActor
@Suite struct HaloUnsavedGuardTests {
    @Test func buttonsAreHalosCloseIDs() {
        let hooks = HaloBox().hooks
        #expect(hooks.idPrefix == "halo")
        #expect(UnsavedGuard.identifier(.save, prefix: hooks.idPrefix) == "halo.close.save")
        #expect(UnsavedGuard.identifier(.dontSave, prefix: hooks.idPrefix) == "halo.close.dontSave")
        #expect(UnsavedGuard.identifier(.cancel, prefix: hooks.idPrefix) == "halo.close.cancel")
    }

    @Test func nameIsTheProjects() throws {
        #expect(HaloBox().hooks.documentName() == nil, "a project with nothing in it still named a document")
        let box = try HaloBox.twoComps(edited: true)
        #expect(box.hooks.documentName() == "Untitled")
        box.model.didSave(name: "Spot", path: "/tmp/HaloUnsavedGuardTests/Spot.halo")
        #expect(box.hooks.documentName() == "Spot")
    }

    @Test func dirtyIsTheDocumentSession() throws {
        let clean = try HaloBox.twoComps(edited: false)
        #expect(!clean.hooks.isDirty(), "the fixture as opened read dirty")
        let edited = try HaloBox.twoComps(edited: true)
        #expect(edited.hooks.isDirty())
        #expect(edited.hooks.isDirty() == edited.model.session.isDirty)
        edited.model.didFailSave("The disk is full.")
        #expect(edited.hooks.isDirty(), "a failed save read clean")
    }

    @Test func saveRunsFileSaveAndLandsWhenClean() async throws {
        let box = try HaloBox.twoComps(edited: true)
        let landed = await box.hooks.save()
        #expect(box.saves == 1, "Save ran File > Save \(box.saves) times")
        #expect(landed && !box.model.session.isDirty)
    }

    @Test func cancelledSaveDoesNotLand() async throws {
        let box = try HaloBox.twoComps(edited: true)
        box.saveTo = nil
        let landed = await box.hooks.save()
        #expect(box.saves == 1)
        #expect(!landed, "a Save that wrote nothing let the window close")
        #expect(box.model.session.isDirty)
    }

    /// ⌘W on a dirty project asks once, in Halo's words; Cancel keeps the window, Don't Save closes it.
    @Test func closeOnDirtyAsksAndCancelStops() async throws {
        let box = try HaloBox.twoComps(edited: true)
        #expect(await !UnsavedGuard.proceed(box.hooks, in: nil), "Cancel let the window close")
        #expect(box.asked == ["halo:Untitled"], "asked \(box.asked)")
        #expect(box.saves == 0 && box.model.session.isDirty)
        box.answer = .dontSave
        #expect(await UnsavedGuard.proceed(box.hooks, in: nil), "Don't Save kept the window")
        #expect(box.saves == 0)
    }

    @Test func cleanGoesOnWithoutAsking() async throws {
        let clean = try HaloBox.twoComps(edited: false)
        #expect(await UnsavedGuard.proceed(clean.hooks, in: nil), "a clean window was stopped")
        #expect(clean.asked.isEmpty && clean.saves == 0)
    }

    /// Open over a dirty project asks first: Save on the untitled project opens the Save panel, and a
    /// cancelled panel stops the open; once the save lands the open goes on.
    @Test func openOnDirtyAsksBeforeReplacing() async throws {
        let box = try HaloBox.twoComps(edited: true)
        box.answer = .save
        box.saveTo = nil
        #expect(await !UnsavedGuard.proceed(box.hooks, in: nil), "a cancelled Save panel let Open replace the project")
        #expect(box.asked == ["halo:Untitled"] && box.saves == 1)
        box.saveTo = "/tmp/HaloUnsavedGuardTests/Spot.halo"
        #expect(await UnsavedGuard.proceed(box.hooks, in: nil), "a landed Save stopped the open")
        #expect(box.saves == 2 && !box.model.session.isDirty)
    }

    /// The window puts the guard on its root and asks through `proceed` before Open, with no alert of its own.
    @Test func windowWiresTheGuard() throws {
        let app = try packageRoot().appending(path: "Sources/HaloApp")
        let window = try String(contentsOf: app.appending(path: "HaloWindow.swift"), encoding: .utf8)
        #expect(window.contains(".unsavedChangesGuard(Self.unsavedHooks("), "the window's close asks nothing")
        let files = try String(contentsOf: app.appending(path: "HaloWindow+File.swift"), encoding: .utf8)
        #expect(files.contains("UnsavedGuard.proceed("), "Open replaces a dirty project unasked")
        #expect(!files.contains("Save changes to"), "Halo's own unsaved alert is still there")
    }
}
#endif
