// FlareSuiteDocumentTests.swift (file-flow FL-2): the open animation as the suite names it, which File >
// Open In ▸ hands to another app. A document opened from or saved to a file is that file; with no document,
// or before it has a file on disk, there is none. Runs on Linux and macOS.
import FlareModel
import SuiteModel
import Testing

@Suite struct FlareSuiteDocumentTests {
    /// A workspace with Bounce open from `path`, as the window's open does it.
    private func bounce(_ path: String = "/w/Bounce.flare") throws -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .fake())
        let document = try #require(FlareFixtures.named("bounce"))
        workspace.finishOpen(.success(document), named: "Bounce.flare")
        workspace.noteRecent(path)
        return workspace
    }

    @Test func anOpenFlareIsItsFile() throws {
        let document = try #require(try bounce().suiteDocument)
        #expect(document.path == "/w/Bounce.flare")
        #expect(document.fileID == SuiteDocumentRef.fileID(forPath: "/w/Bounce.flare"))
        #expect(document.app == .flare)
        #expect(document.type == .flareAnimation)
        #expect(document.displayName == "Bounce.flare")
    }

    @Test func noDocumentHandsNothing() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.noteRecent("/w/Bounce.flare")
        #expect(workspace.suiteDocument == nil)
    }

    @Test func anUnsavedDocumentHandsNothing() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.noteRecent("/w/Bounce.flare")
        workspace.newDocument()
        #expect(workspace.suiteDocument == nil, "a new animation isn't Bounce.flare")
    }

    @Test func anotherRecentFileIsNotTheDocument() throws {
        var workspace = try bounce()
        workspace.noteRecent("/w/Title.flare")
        #expect(workspace.suiteDocument == nil, "the newest recent is Title.flare, not the open Bounce.flare")
    }
}
