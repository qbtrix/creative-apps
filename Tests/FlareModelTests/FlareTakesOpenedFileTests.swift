// FlareTakesOpenedFileTests.swift: `takesOpenedFile`, whether a window may open
// a file handed to the app in place (SuiteOpenQueue) instead of in a new
// window: only with no animation open and no open under way. Runs on Linux
// and macOS.
import FlareCore
import FlareModel
import Testing

struct FlareTakesOpenedFileTests {
    @Test func onlyAnEmptyIdleWindowTakesAFile() throws {
        var workspace = FlareWorkspace(services: .fake())
        #expect(workspace.takesOpenedFile)
        workspace.beginOpen()
        #expect(!workspace.takesOpenedFile)
        workspace.finishOpen(.failure(.malformed("bad")), named: "Bad.flare")
        #expect(workspace.takesOpenedFile)
        let document = Document(scenes: [FlareScene(id: "scene-1", name: "Scene 1", durationFrames: 30, layers: [])])
        workspace.finishOpen(.success(document), named: "Title.flare")
        #expect(!workspace.takesOpenedFile)
    }
}
