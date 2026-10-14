// FlareRecentTests.swift: the Open Recent list in FlareWorkspace (FlareFiles.swift, MP-1 of
// docs/blueprints/flare/features/mac-platform.md): most recent first, deduplicated by exact path, at most
// `recentLimit` entries, cleared on request and kept across a new document. Runs on Linux and macOS.
@testable import FlareModel
import Testing

@Suite("Open Recent list")
struct FlareRecentTests {
    @Test("noting a path again moves it to the front without a duplicate")
    func movesToFront() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.noteRecent("/a.flare")
        workspace.noteRecent("/b.flare")
        workspace.noteRecent("/a.flare")
        #expect(workspace.recent == ["/a.flare", "/b.flare"])
    }

    @Test("eleven distinct paths keep the ten most recent")
    func keepsTheLimit() {
        var workspace = FlareWorkspace(services: .fake())
        let paths = (0...10).map { "/files/\($0).flare" }
        for path in paths { workspace.noteRecent(path) }
        #expect(FlareWorkspace.recentLimit == 10)
        #expect(workspace.recent.count == 10)
        #expect(workspace.recent == Array(paths.dropFirst().reversed()))
        #expect(!workspace.recent.contains("/files/0.flare"))
    }

    @Test("two files with one name in different folders stay two entries")
    func sameNameDifferentFolders() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.noteRecent("/x/a.flare")
        workspace.noteRecent("/y/a.flare")
        #expect(workspace.recent == ["/y/a.flare", "/x/a.flare"])
    }

    @Test("clearRecent empties the list")
    func clears() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.noteRecent("/a.flare")
        workspace.noteRecent("/b.flare")
        workspace.clearRecent()
        #expect(workspace.recent.isEmpty)
    }

    @Test("a new document leaves the list as it was")
    func newDocumentKeepsRecent() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.noteRecent("/a.flare")
        workspace.noteRecent("/b.flare")
        workspace.newDocument()
        #expect(workspace.recent == ["/b.flare", "/a.flare"])
    }
}
