// MacPlatformJourneyTests.swift: journey steps 1-3 of the mac-platform feature
// (docs/blueprints/flare/features/mac-platform.md) walked through FlareWorkspace on the bounce sample: Open Recent
// after an open and a save-as, autosave due 30 s after an edit with recovery bytes that decode to the edit, and a
// restore that lands as unsaved, untitled work outside Open Recent. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import Testing

struct MacPlatformJourneyTests {
    @Test func openSaveEditRecoverRestore() throws {
        var workspace = FlareWorkspace(services: .fake())

        // Step 1: open a file, then save it as another; each path goes to Open Recent, most recent first.
        try workspace.open(FlareFormat.encode(FlareFixtures.bounce), named: "Bounce.flare")
        workspace.noteRecent("/work/Bounce.flare")
        let saved = workspace.saveData()
        let save = try #require(saved)
        workspace.didSave(save, named: "Bounce Copy.flare")
        workspace.noteRecent("/work/Bounce Copy.flare")
        #expect(workspace.title == "Bounce Copy")
        #expect(workspace.recent == ["/work/Bounce Copy.flare", "/work/Bounce.flare"])
        #expect(workspace.isDirty == false)

        // Step 2: edit, then 30 s later autosave is due and the recovery bytes decode to the edit.
        workspace.addLayer()
        #expect(workspace.isDirty)
        #expect(workspace.autosaveDue(lastEdit: 100, now: 129.9) == false)
        #expect(workspace.autosaveDue(lastEdit: 100, now: 130))
        let data = try #require(workspace.recoveryData())
        let recovered = try FlareWorkspace.decodeFile(data).get()
        #expect(recovered == workspace.document)
        #expect(recovered != FlareFixtures.bounce)

        // Step 3: on the next launch, restore it: unsaved, untitled, and Open Recent as it was.
        var relaunched = FlareWorkspace(services: .fake())
        relaunched.noteRecent("/work/Bounce.flare")
        relaunched.noteRecent("/work/Bounce Copy.flare")
        let recentBefore = relaunched.recent
        relaunched.restoreRecovery(recovered)
        #expect(relaunched.document == recovered)
        #expect(relaunched.isDirty)
        #expect(relaunched.fileName == nil)
        #expect(relaunched.title == "Untitled")
        #expect(relaunched.recent == recentBefore)
        #expect(relaunched.canUndo == false)
    }
}
