// PhotoLiveTextTests.swift: the Photo window's launch workspace draws text with the suite's live text service
// (LiveText, Core Text), not PhotoServices' FakeText default, which draws a clear frame: so text a user types
// with the Type tool shows in the picture once committed (#5191). macOS only.
import PhotoModel
import SuiteKernel
import SuiteShell
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoLiveTextTests {
    @Test func theLaunchWorkspaceDrawsTextLive() throws {
        var workspace = PhotoWindow.launchWorkspace()
        #expect(workspace.services.text is LiveText, "Photo's window draws text with \(type(of: workspace.services.text))")

        try workspace.newCanvas(width: 400, height: 200)
        let before = try workspace.composite().rgba8()
        let params = JSONValue.object(["x": .number(40), "y": .number(60), "words": .string("SALE")])
        _ = try #require(PhotoWorkspace.catalog).run("text.add", params: params, on: &workspace)
        #expect(try workspace.composite().rgba8() != before, "the committed text layer left the picture unchanged")
    }
}
