// FlareSaveStatusTests.swift: the window's save status (FlareSaveStatus.swift,
// docs/blueprints/flare/features/layers-files.md, LF-5). A failed save reads
// "Not saved" and keeps reading it until a save succeeds; an open document
// that never failed a save has no status. Runs on Linux and macOS.
import FlareCore
@testable import FlareModel
import Testing

struct FlareSaveStatusTests {
    private func bounce() -> FlareWorkspace {
        FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
    }

    @Test func noStatusBeforeAnySave() {
        var workspace = bounce()
        #expect(workspace.saveStatus == nil)
        workspace.addLayer()
        #expect(workspace.isDirty)
        #expect(workspace.saveStatus == nil, "an unsaved edit alone isn't a failed save")
    }

    @Test func saveFailedGivesNotSaved() {
        var workspace = bounce()
        workspace.addLayer()
        workspace.saveFailed("You don't have permission to save the file.")
        #expect(workspace.saveStatus == "Not saved")
        #expect(workspace.isDirty, "a failed save keeps the changes")
    }

    @Test func didSaveClearsNotSaved() throws {
        var workspace = bounce()
        workspace.addLayer()
        workspace.saveFailed("The volume is read only.")
        #expect(workspace.saveStatus == "Not saved")
        let data = workspace.saveData()
        let save = try #require(data)
        workspace.didSave(save, named: "Bounce.flare")
        #expect(workspace.saveStatus == nil)
        #expect(!workspace.isDirty)
    }

    @Test func nothingToSaveAlsoSaysNotSaved() {
        var workspace = FlareWorkspace(services: .fake())
        let data = workspace.saveData()
        #expect(data == nil)
        #expect(workspace.saveStatus == "Not saved")
    }

    @Test func openingAnotherDocumentClearsTheStatus() {
        var workspace = bounce()
        workspace.saveFailed("The disk is full.")
        workspace.restoreRecovery(FlareFixtures.bounce)
        #expect(workspace.saveStatus == nil)
    }
}
