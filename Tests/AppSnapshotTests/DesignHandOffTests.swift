// DesignHandOffTests.swift (#5200): a .design file handed to Design the way the
// launcher's Open In and the home's Recent hand it (an .aghandoff file the
// suite delegate receives), and the way Finder opens it (the file's own URL),
// reaches Design's host as DesignShell wires it and loads the file's pages; a
// `.new` hand-off (the welcome's Blank, #3333) asks a window for a new file.
// Each test has its own open queue, so a window another test mounted never takes the file.
import DesignModel
import Foundation
import SuiteModel
import SuiteShell
import SuiteUI
import Testing
@testable import DesignApp

@MainActor @Suite(.serialized) struct DesignHandOffTests {
    private let folder = FileManager.default.temporaryDirectory
        .appendingPathComponent("DesignHandOff-\(UUID().uuidString)")

    /// A real .design file with one named page.
    private func designFile() throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let page = DesignPage(id: "p1", name: "Handed Page", frameWidth: 800, frameHeight: 600)
        let url = folder.appendingPathComponent("Logo.design")
        try DesignWorkspace().services.filing.encode(DesignDocument(pages: [page])).write(to: url)
        return url
    }

    private let queue = SuiteOpenQueue(windowID: DesignLaunch.windowID)

    private func delegate(store: FileStore) -> SuiteAppDelegate {
        let delegate = SuiteAppDelegate()
        delegate.app = .design
        delegate.host = DesignShell.host(opening: queue)
        delegate.receiver = StoreHandOffs(store: store, from: .launcher) { _, app async throws(SuiteError) -> SwitchReceipt in
            SwitchReceipt(app: app, wasRunning: true, requestedAt: 0)
        }
        return delegate
    }

    /// The file a window takes from the open queue, opened as DesignWindow opens it.
    private func openedByAWindow() throws -> DesignWorkspace {
        guard case .file(let url) = queue.windowAppeared(requestWindow: {}) else {
            throw DesignHandOffMissing()
        }
        var workspace = DesignWorkspace()
        try workspace.open(Data(contentsOf: url), at: url)
        return workspace
    }

    @Test func openInFromTheLauncherLoadsTheFile() async throws {
        let file = try designFile()
        let store = FileStore(folder: folder.path)
        let document = try #require(SuiteAppDelegate.document(for: file))
        let handOff = HandOff(id: HandOff.newID(), from: .launcher, to: .design, verb: .open,
                              documents: [document], createdAt: Date())
        try store.writeData("handoffs/\(handOff.id).aghandoff", try HandOffCodec.encode(handOff))

        await delegate(store: store).handle(URL(fileURLWithPath: store.folder + "/handoffs/\(handOff.id).aghandoff"))

        let settled = try #require(try store.readData("handoffs/\(handOff.id).aghandoff"))
        #expect(try HandOffCodec.decode(settled).state == .accepted)
        let opened = try openedByAWindow()
        #expect(opened.pages.map(\.name) == ["Handed Page"])
        #expect(opened.documentURL == file)
    }

    /// #3333: the welcome's Blank sends `.new` to Design; it's accepted and a window takes a new file.
    @Test func aNewFromTheWelcomeAsksForANewFile() async throws {
        let store = FileStore(folder: folder.path)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let preset = NewDocumentPreset(id: "design.blank", app: .design, title: "Blank", detail: "One page")
        let handOff = SuiteCreating().handOff(for: preset, id: HandOff.newID(), at: Date())
        try store.writeData("handoffs/\(handOff.id).aghandoff", try HandOffCodec.encode(handOff))

        await delegate(store: store).handle(URL(fileURLWithPath: store.folder + "/handoffs/\(handOff.id).aghandoff"))

        let settled = try #require(try store.readData("handoffs/\(handOff.id).aghandoff"))
        #expect(try HandOffCodec.decode(settled).state == .accepted)
        #expect(queue.windowAppeared(requestWindow: {}) == .newDocument)
    }

    @Test func aFinderOpenLoadsTheFile() async throws {
        let file = try designFile()

        await delegate(store: FileStore(folder: folder.path)).handle(file)

        let opened = try openedByAWindow()
        #expect(opened.pages.map(\.name) == ["Handed Page"])
    }
}

private struct DesignHandOffMissing: Error {}
