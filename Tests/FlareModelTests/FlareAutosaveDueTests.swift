// FlareAutosaveDueTests.swift: the autosave due time and the recovery bytes in FlareWorkspace (FlareFiles.swift,
// docs/blueprints/flare/features/mac-platform.md, MP-2). Autosave is due only while the document is dirty, once
// `autosaveDelay` seconds have passed since the last edit; `recoveryData()` is the dirty document's file bytes.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import Testing

private func opened() throws -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    try workspace.open(FlareFormat.encode(FlareFixtures.bounce), named: "Bounce.flare")
    return workspace
}

private func edited() throws -> FlareWorkspace {
    var workspace = try opened()
    workspace.addLayer()
    return workspace
}

struct FlareAutosaveDueTests {
    @Test func delayIsThirtySeconds() {
        #expect(FlareWorkspace.autosaveDelay == 30)
    }

    @Test func anEditIsDueAfterTheDelay() throws {
        let workspace = try edited()
        #expect(workspace.isDirty)
        #expect(workspace.autosaveDue(lastEdit: 0, now: 0) == false)
        #expect(workspace.autosaveDue(lastEdit: 0, now: 29.9) == false)
        #expect(workspace.autosaveDue(lastEdit: 0, now: 30.0))
        #expect(workspace.autosaveDue(lastEdit: 0, now: 300))
    }

    @Test func cleanIsNeverDue() throws {
        let workspace = try opened()
        #expect(workspace.isDirty == false)
        #expect(workspace.autosaveDue(lastEdit: 0, now: 30) == false)
        #expect(workspace.autosaveDue(lastEdit: 0, now: 10_000) == false)
        #expect(FlareWorkspace(services: .fake()).autosaveDue(lastEdit: 0, now: 10_000) == false)
    }

    @Test func noLastEditIsNotDue() throws {
        let workspace = try edited()
        #expect(workspace.autosaveDue(lastEdit: nil, now: 10_000) == false)
    }

    @Test func afterASaveIsNotDue() throws {
        var workspace = try edited()
        let saved = workspace.saveData()
        let save = try #require(saved)
        workspace.didSave(save, named: "Bounce.flare")
        #expect(workspace.autosaveDue(lastEdit: 0, now: 60) == false)
        #expect(workspace.recoveryData() == nil)
    }

    @Test func undoBackToTheSaveIsNotDue() throws {
        var workspace = try edited()
        #expect(workspace.autosaveDue(lastEdit: 0, now: 60))
        workspace.undo()
        #expect(workspace.isDirty == false)
        #expect(workspace.autosaveDue(lastEdit: 0, now: 60) == false)
        #expect(workspace.recoveryData() == nil)
    }

    @Test(arguments: [
        (Double.nan, 60.0), (0.0, Double.nan), (Double.nan, Double.nan),
        (0.0, Double.infinity), (-Double.infinity, 0.0),
    ])
    func nonFiniteTimesAreNotDue(lastEdit: Double, now: Double) throws {
        let workspace = try edited()
        #expect(workspace.autosaveDue(lastEdit: lastEdit, now: now) == false)
    }

    @Test func recoveryDataDecodesToTheDocument() throws {
        let workspace = try edited()
        let data = try #require(workspace.recoveryData())
        let decoded = try FlareWorkspace.decodeFile(data).get()
        #expect(decoded == workspace.document)
        #expect(decoded != FlareFixtures.bounce)
    }

    @Test func recoveryDataIsNilWhenClean() throws {
        #expect(try opened().recoveryData() == nil)
        #expect(FlareWorkspace(services: .fake()).recoveryData() == nil)
    }
}
