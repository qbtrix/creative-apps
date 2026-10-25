// DesignUnsavedGuardTests.swift (adopt-kernel-unsaved-prompt UP-5, on since UP-6): the hooks a Design window
// hands SuiteUI's `.unsavedChangesGuard` (DesignWindow.unsavedHooks). Their buttons are `design.close.*`; the
// name is the open file's ("Untitled" before its first save, nil with nothing open); the dirty state is the
// workspace's DocumentSession; and Save runs File > Save (`DesignIntent.save` through the window's perform),
// landing only when the workspace then reads clean, so a cancelled Save panel or a failed write keeps the
// window. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import Foundation
import SuiteKernel
import Testing

@testable import DesignApp
@testable import SuiteUI

/// The window's workspace and the intents its perform received, for the hooks to read and the tests to count.
@MainActor private final class DesignBox {
    var model = DesignWorkspace()
    var saves = 0
    /// What File > Save does here: writes (marks the workspace saved at `url`) or, with nil, lands nothing.
    var saveTo: URL? = URL(fileURLWithPath: "/tmp/Poster.design")

    var hooks: UnsavedHooks {
        DesignWindow.unsavedHooks(model: { self.model }) { intent in
            guard case .save = intent else { return }
            self.saves += 1
            if let url = self.saveTo { self.model.didSave(to: url) }
        }
    }

    /// The `cards` fixture, opened unsaved, with one rectangle drawn on it when `edited`.
    static func cards(edited: Bool) throws -> DesignBox {
        let box = DesignBox()
        box.model.useServices(.fake)
        let opened = box.model.openFixture("cards")
        #expect(opened)
        if edited {
            try box.model.addNode(.rectangle, frame: DesignRect(x: 40, y: 80, width: 96, height: 96), in: "node-1")
        }
        return box
    }
}

@MainActor
@Suite struct DesignUnsavedGuardTests {
    @Test func buttonsAreDesignsCloseIDs() {
        let hooks = DesignBox().hooks
        #expect(hooks.idPrefix == "design")
        #expect(UnsavedGuard.identifier(.save, prefix: hooks.idPrefix) == "design.close.save")
        #expect(UnsavedGuard.identifier(.dontSave, prefix: hooks.idPrefix) == "design.close.dontSave")
        #expect(UnsavedGuard.identifier(.cancel, prefix: hooks.idPrefix) == "design.close.cancel")
    }

    @Test func nameIsTheOpenFiles() throws {
        #expect(DesignBox().hooks.documentName() == nil, "nothing open still named a document")
        let box = try DesignBox.cards(edited: true)
        #expect(box.hooks.documentName() == "Untitled")
        box.model.didSave(to: URL(fileURLWithPath: "/tmp/Poster.design"))
        #expect(box.hooks.documentName() == "Poster.design")
    }

    @Test func dirtyIsTheDocumentSession() throws {
        let clean = try DesignBox.cards(edited: false)
        #expect(!clean.hooks.isDirty(), "the fixture as opened read dirty")
        let edited = try DesignBox.cards(edited: true)
        #expect(edited.hooks.isDirty())
        #expect(edited.hooks.isDirty() == edited.model.documentSession.isDirty)
        edited.model.undo()
        #expect(!edited.hooks.isDirty(), "undoing back to the open read dirty")
    }

    @Test func saveRunsFileSaveAndLandsWhenClean() async throws {
        let box = try DesignBox.cards(edited: true)
        let landed = await box.hooks.save()
        #expect(box.saves == 1, "Save ran File > Save \(box.saves) times")
        #expect(landed && !box.model.isDirty)
    }

    @Test func cancelledSaveDoesNotLand() async throws {
        let box = try DesignBox.cards(edited: true)
        box.saveTo = nil
        let landed = await box.hooks.save()
        #expect(box.saves == 1)
        #expect(!landed, "a Save that wrote nothing let the window close")
        #expect(box.model.isDirty)
    }

    @Test func guardAsksOnlyWhenDirty() async throws {
        let clean = try DesignBox.cards(edited: false)
        #expect(await UnsavedGuard.proceed(clean.hooks, in: nil), "a clean window was stopped")
        #expect(clean.saves == 0)
    }
}
#endif
