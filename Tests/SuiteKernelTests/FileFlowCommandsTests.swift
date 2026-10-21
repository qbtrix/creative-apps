// FileFlowCommandsTests.swift (file-flow SF-1, on at SF-6, KJ-files): the file-flow commands run the target's one
// method once, with the right why-nots, on a test target.
import Foundation
import Testing
import SuiteKernel

/// A target with a recent list, routing like the suite's registry, that records what it was asked to do.
struct FileFlowProbe: FileFlowTarget {
    var appID = "photo"
    var recentFiles: [RecentFileEntry] = [
        RecentFileEntry(fileID: "path:/w/Sky.photo", name: "Sky", path: "/w/Sky.photo", app: "photo", lastUsed: Date(timeIntervalSince1970: 200)),
        RecentFileEntry(fileID: "path:/w/Gone.photo", name: "Gone", path: "/w/Gone.photo", app: "photo", lastUsed: Date(timeIntervalSince1970: 100)),
    ]
    var hasDocument = true
    var placesExtensions: Set<String> = ["png"]
    var openInApps: [String] = []
    var openInHelp: String? = "No other app opens Photo documents files."
    var missing: Set<String> = ["path:/w/Gone.photo"]
    var opened: [String] = [], handedTo: [String] = [], performed: [[DropAction]] = []

    func readers(ofExtension ext: String) -> [String] { ext == "png" ? ["photo", "library"] : ext == "halo" ? ["halo"] : [] }
    mutating func openRecent(_ fileID: String) throws {
        if missing.contains(fileID), let gone = recentFiles.first(where: { $0.fileID == fileID }) {
            recentFiles.removeAll { $0.fileID == fileID }
            throw CatalogError.failed(id: "file.open-recent", message: "\(gone.name) is missing. It was removed from Recent Files.")
        }
        opened.append(fileID)
    }
    mutating func clearRecent() throws { recentFiles = [] }
    mutating func openIn(_ app: String) throws { handedTo.append(app) }
    mutating func perform(_ actions: [DropAction]) throws { performed.append(actions) }

    static var catalog: CommandCatalog<FileFlowProbe>? {
        try? CommandCatalog(app: "photo", FileFlowCommands.specs(FileFlowProbe.self), history: { _ in History<Int>() })
    }
}

@Suite struct FileFlowCommandsTests {
    /// The five ids and kinds are declared now, before any body runs.
    @Test func theFiveCommandsAreDeclared() throws {
        let catalog = try #require(FileFlowProbe.catalog)
        #expect(catalog.ids == ["file.clear-recent", "file.drop", "file.open-in", "file.open-recent", "file.recent"])
        let kinds = Dictionary(uniqueKeysWithValues: catalog.describeAll().map { ($0.id, $0.kind) })
        #expect(kinds == ["file.recent": .query, "file.open-recent": .file, "file.clear-recent": .view,
                          "file.open-in": .file, "file.drop": .file])
    }

    @Test func dropPlansOnceAndPerformsOnce() throws {
        let catalog = try #require(FileFlowProbe.catalog)
        var probe = FileFlowProbe()
        let outcome = try catalog.run("file.drop", params: .object(["paths": .array([.string("/w/a.png"), .string("/w/b.halo")])]),
                                      on: &probe)
        #expect(probe.performed == [[.place(path: "/w/a.png"), .handOff(path: "/w/b.halo", app: "halo")]])
        #expect(try outcome.result.decode([DropAction].self) == probe.performed.first)
    }

    @Test func openInWithHelpIsUnavailableWithIt() throws {
        let catalog = try #require(FileFlowProbe.catalog)
        var probe = FileFlowProbe()
        #expect(catalog.availability("file.open-in", on: probe).why == "No other app opens Photo documents files.")
        probe.openInHelp = nil; probe.openInApps = ["library"]
        _ = try catalog.run("file.open-in", params: .object(["app": .string("library")]), on: &probe)
        #expect(probe.handedTo == ["library"])
    }

    @Test func clearRecentOnAnEmptyListIsUnavailable() throws {
        let catalog = try #require(FileFlowProbe.catalog)
        var probe = FileFlowProbe()
        _ = try catalog.run("file.clear-recent", params: .object([:]), on: &probe)
        #expect(probe.recentFiles.isEmpty)
        #expect(catalog.availability("file.clear-recent", on: probe).why == "No Recent Files")
    }

    @Test func openRecentOpensOrSaysTheFileIsGone() throws {
        let catalog = try #require(FileFlowProbe.catalog)
        var probe = FileFlowProbe()
        let listed = try catalog.run("file.recent", params: .object([:]), on: &probe).result.decode([RecentFileEntry].self)
        #expect(listed.map(\.name) == ["Sky", "Gone"])
        _ = try catalog.run("file.open-recent", params: .object(["fileID": .string("path:/w/Sky.photo")]), on: &probe)
        #expect(probe.opened == ["path:/w/Sky.photo"])
        #expect(throws: CatalogError.failed(id: "file.open-recent", message: "Gone is missing. It was removed from Recent Files.")) {
            try catalog.run("file.open-recent", params: .object(["fileID": .string("path:/w/Gone.photo")]), on: &probe)
        }
        #expect(throws: CatalogError.self) {
            try catalog.run("file.open-recent", params: .object(["fileID": .string("path:/w/Never.photo")]), on: &probe)
        }
    }
}
