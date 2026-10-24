// FlareRecoveryRestoreTests.swift: restoring a recovered document in FlareWorkspace (FlareFiles.swift,
// docs/blueprints/flare/features/mac-platform.md, MP-3). `restoreRecovery` lands the document as unsaved work:
// dirty, untitled and no undo history, and no longer the file it came from, so Open In
// offers nothing until a save. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import Testing

struct FlareRecoveryRestoreTests {
    @Test func restoreLandsAsUnsavedWork() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.noteRecent("/a/Walk.flare")
        workspace.restoreRecovery(FlareFixtures.bounce)
        #expect(workspace.document == FlareFixtures.bounce)
        #expect(workspace.isDirty)
        #expect(workspace.fileName == nil)
        #expect(workspace.title == "Untitled")
        #expect(workspace.suiteDocument == nil, "the restored work stands for /a/Walk.flare")
        #expect(workspace.canUndo == false)
    }

    @Test func restoreOverANamedFileDropsTheNameAndItsFile() throws {
        var workspace = FlareWorkspace(services: .fake())
        try workspace.open(FlareFormat.encode(FlareFixtures.bounce), named: "Bounce.flare")
        workspace.noteRecent("/a/Bounce.flare")
        workspace.addLayer()
        #expect(workspace.canUndo)
        workspace.restoreRecovery(FlareFixtures.bounce)
        #expect(workspace.document == FlareFixtures.bounce)
        #expect(workspace.isDirty)
        #expect(workspace.fileName == nil)
        #expect(workspace.title == "Untitled")
        #expect(workspace.suiteDocument == nil, "the restored work stands for /a/Bounce.flare")
        #expect(workspace.canUndo == false)
        #expect(workspace.recoveryData() != nil)
    }
}
