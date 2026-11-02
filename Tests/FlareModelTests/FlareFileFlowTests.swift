// FlareFileFlowTests.swift: MFL, Flare's file-flow Model walk (file-flow
// FL-1 written, FL-3 turns it on). Flare as a FileFlowTarget and a
// SuiteDocumentHost: it names itself "flare", opens a dropped .flare, hands
// a .halo to Halo, refuses an SVG (the host with "Flare can't import SVG
// yet.") until SVG import (E11), accepts open and new hand-offs, reads its
// recents from the suite's list and keeps no list of its own (#5126), registers the
// shared file-flow ids, and runs RJ-F42 (Tests/RealJobs/flare/open-recent)
// on the catalog. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareModel
import SuiteKernel
import SuiteModel
import Testing

/// A workspace with a new document open.
private func opened() -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    workspace.newDocument()
    return workspace
}

/// A workspace with RJ-F42's bounce animation open from `path`, as the window leaves it after an open.
private func openedFile(_ path: String = "/w/Bounce.flare") throws -> FlareWorkspace {
    var workspace = FlareWorkspace(services: .fake())
    try workspace.open(Data(FlareJob.bounce.utf8), named: path.split(separator: "/").last.map(String.init) ?? path)
    workspace.noteRecent(path)
    return workspace
}

/// A hand-off from Library to Flare for `path`.
private func handOff(_ verb: HandOffVerb, path: String = "/w/Bounce.flare",
                     type: SuiteTypeID = .flareAnimation) -> HandOff {
    let name = path.split(separator: "/").last.map(String.init) ?? path
    let ref = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .library,
                               type: type, displayName: name)
    return HandOff(id: HandOff.newID(), from: .library, to: .flare, verb: verb, documents: [ref],
                   createdAt: Date(timeIntervalSince1970: 0))
}

/// A recent-file entry for `path`, as the bridge maps the suite's list.
private func entry(_ path: String) -> RecentFileEntry {
    RecentFileEntry(fileID: SuiteDocumentRef.fileID(forPath: path), name: path.split(separator: "/").last.map(String.init) ?? path,
                    path: path, app: "flare", lastUsed: Date(timeIntervalSince1970: 0))
}

/// A temp folder for one test, never the user's support folder.
private func tempFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("FlareFileFlow-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

/// The standard registry with Halo also reading .flare, as flare-in-halo (FH-1) will have it.
private let haloReadsFlare = SuiteTypeRegistry(types: SuiteTypeRegistry.standard.types.map {
    $0.id == .flareAnimation ? SuiteDocumentType(id: $0.id, name: $0.name, extensions: $0.extensions, owner: $0.owner,
                                                 readers: $0.readers + [.halo]) : $0
})

/// Runs Clear Menu the way the shared command does, through the protocol.
private func clearThroughFileFlow<T: FileFlowTarget>(_ target: inout T) throws { try target.clearRecent() }

/// MFL, the behaviour FL-3 turns on.
@Suite struct FlareFileFlowTests {
    /// The drop rule for one path into `target`.
    private func plan(_ target: FlareWorkspace, _ path: String) -> [DropAction] {
        DropPlan.plan([path], into: target.appID, hasDocument: target.hasDocument,
                      places: target.placesExtensions, readers: { target.readers(ofExtension: $0) })
    }

    @Test func flareNamesItselfAndPlacesNothingYet() {
        let workspace = FlareWorkspace(services: .fake())
        #expect(workspace.appID == "flare")
        #expect(workspace.placesExtensions.isEmpty)
        #expect(!workspace.hasDocument && opened().hasDocument)
    }

    @Test func aFlareOpensAndAHaloGoesToHalo() throws {
        var workspace = opened()
        #expect(plan(workspace, "/w/Bounce.flare") == [.open(path: "/w/Bounce.flare")])
        #expect(plan(workspace, "/w/Intro.halo") == [.handOff(path: "/w/Intro.halo", app: "halo")])
        try workspace.perform(plan(workspace, "/w/Bounce.flare") + plan(workspace, "/w/Intro.halo"))
        #expect(workspace.takeFileRequests() == [.open(path: "/w/Bounce.flare"), .handOff(path: "/w/Intro.halo", app: "halo")])
        #expect(workspace.takeFileRequests().isEmpty)
    }

    @Test func anSVGIsRefusedUntilSVGImport() async throws {
        var workspace = opened()
        let before = workspace.document
        let actions = plan(workspace, "/w/logo.svg")
        guard case .refuse(let path, _)? = actions.first, actions.count == 1 else {
            Issue.record("an SVG wasn't refused: \(actions)")
            return
        }
        #expect(path == "/w/logo.svg")
        try workspace.perform(actions)
        #expect(workspace.document == before)
        #expect(workspace.undoActionName == nil)
        #expect(workspace.takeFileRequests().isEmpty, "a refused SVG was opened or handed off")
        let place = handOff(.place, path: "/w/logo.svg", type: .svg)
        #expect(await workspace.refusal(for: place) == .notAvailable(FlareWorkspace.svgRefusal))
        #expect(FlareWorkspace.svgRefusal == "Flare can't import SVG yet.")
    }

    @Test func openInOffersHaloForAFlare() throws {
        var workspace = try openedFile()
        #expect(workspace.openInApps.isEmpty, "Halo reads .flare only from flare-in-halo (FH-1)")
        #expect(workspace.openInHelp == SuiteError.noOtherReader(typeName: "Flare Animation").message)
        workspace.updateFileFlow(recents: [], registry: haloReadsFlare)
        #expect(workspace.openInApps == ["halo"])
        #expect(workspace.openInHelp == nil)
        try workspace.openIn("halo")
        #expect(workspace.takeFileRequests() == [.handOff(path: "/w/Bounce.flare", app: "halo")])
        #expect(FlareWorkspace(services: .fake()).openInHelp == "Open an animation first.")
        var unsaved = opened()
        unsaved.updateFileFlow(recents: [], registry: haloReadsFlare)
        #expect(unsaved.openInHelp == "Save Untitled first.")
        #expect(throws: CatalogError.self) { try unsaved.openIn("halo") }
    }

    @Test func hostAcceptsOpenAndNewAndRefusesTheRest() async throws {
        let workspace = opened()
        for verb in [HandOffVerb.open, .new] {
            #expect(await workspace.refusal(for: handOff(verb)) == nil)
            #expect(try await workspace.accept(handOff(verb)) == .accepted)
        }
        #expect(await workspace.refusal(for: handOff(.importAnimation)) != nil)
        await #expect(throws: SuiteError.self) { _ = try await workspace.accept(handOff(.edit)) }
    }

    @Test func recentsListAndOpen() throws {
        let here = try tempFolder().appendingPathComponent("Here.flare").path
        try Data(FlareJob.bounce.utf8).write(to: URL(fileURLWithPath: here))
        var workspace = FlareWorkspace(services: .fake())
        workspace.updateFileFlow(recents: [entry(here), entry("/nowhere/Gone.flare")])
        #expect(workspace.recentFiles.map(\.path) == [here, "/nowhere/Gone.flare"])
        try workspace.openRecent(entry(here).fileID)
        #expect(throws: CatalogError.self) { try workspace.openRecent(entry("/nowhere/Gone.flare").fileID) }
        #expect(workspace.recentFiles.map(\.path) == [here], "a missing file stayed in the list")
        #expect(workspace.takeFileRequests() == [.open(path: here), .forget(fileID: entry("/nowhere/Gone.flare").fileID)])
    }

    @Test func clearRecentEmptiesTheSuiteList() throws {
        var workspace = FlareWorkspace(services: .fake())
        workspace.updateFileFlow(recents: [entry("/w/Bounce.flare")])
        try clearThroughFileFlow(&workspace)
        #expect(workspace.recentFiles.isEmpty)
        #expect(workspace.takeFileRequests() == [.clearRecent])
    }

    @Test func openRecentIsTheSuitesListAndFlareKeepsNone() throws {
        var workspace = try openedFile("/w/Bounce.flare")
        workspace.noteRecent("/w/Title.flare")
        #expect(workspace.filePath == "/w/Title.flare", "noting a file didn't make it the open file")
        #expect(workspace.recentFiles.isEmpty, "Open Recent lists files the suite's list doesn't hold")
        #expect(FlareWorkspace.catalog.availability("file.clear-recent", on: workspace).why == "No Recent Files")
        workspace.updateFileFlow(recents: [entry("/w/Intro.flare")])
        #expect(workspace.recentFiles.map(\.path) == ["/w/Intro.flare"])
        #expect(FlareWorkspace.catalog.availability("file.clear-recent", on: workspace).why == nil, "Clear Menu didn't read the suite's list")
    }

    @Test func theSharedIDsAreInTheCatalog() {
        let ids = ["file.recent", "file.open-recent", "file.clear-recent", "file.open-in", "file.drop"]
        #expect(Set(ids).isSubset(of: FlareWorkspace.catalog.ids), "a file-flow id is missing, or a duplicate emptied the catalog")
        #expect(FlareWorkspace.catalog.spec("file.clear-recent")?.title == "Clear Menu")
    }

    /// RJ-F42 on Linux: the CLI keeps file commands window-only, so the walk runs the job's steps here and notes
    /// the save in a temp suite store the way the window's bridge does.
    @Test func openRecentRealJobPasses() async throws {
        let folder = FlareJob.root.appendingPathComponent("open-recent")
        let script = try JSONDecoder().decode(OpenRecentJob.self, from: Data(contentsOf: folder.appendingPathComponent("open-recent.jobs.json")))
        let bounce = folder.appendingPathComponent("input/bounce.flare").path
        var workspace = try openedFile(bounce)
        let recents = StoreRecents(store: FileStore(folder: try tempFolder().path))
        var results: [JSONValue] = []
        for step in script.steps {
            var params = step.params
            if case .object(var fields) = params, case .array(let paths)? = fields["paths"] {
                fields["paths"] = .array(paths.map { if case .string(let p) = $0 { .string(folder.appendingPathComponent(p).path) } else { $0 } })
                params = .object(fields)
            }
            results.append(try FlareWorkspace.catalog.run(step.id, params: params, on: &workspace).result)
            if step.id == "file.save", let ref = workspace.suiteDocument {
                try await recents.note(ref, event: .saved, at: Date(timeIntervalSince1970: 0), thumbnail: nil)
                let items = try await recents.list().items.filter { $0.ref.app == .flare }
                workspace.updateFileFlow(recents: items.map {
                    RecentFileEntry(fileID: $0.ref.fileID, name: $0.ref.displayName, path: $0.ref.path, app: "flare", lastUsed: $0.lastUsed)
                })
            }
        }
        #expect(results.count == 3)
        guard results.count == 3, case .array(let listed) = results[1], case .array(let dropped) = results[2] else { return }
        #expect(listed.count == 1 && workspace.recentFiles.map(\.path) == [bounce], "Open Recent isn't the suite's list")
        #expect(dropped.count == 2)
        let title = folder.appendingPathComponent("input/title.flare").path
        #expect(workspace.takeFileRequests() == [.open(path: title)], "the .flare didn't open, or the SVG did")
    }
}

/// The parts of open-recent.jobs.json the walk runs.
private struct OpenRecentJob: Decodable { var steps: [CommandEnvelope] }

extension FlareJob {
    /// RJ-F42's bounce.flare, a one-scene animation.
    static var bounce: String {
        (try? String(contentsOf: root.appendingPathComponent("open-recent/input/bounce.flare"), encoding: .utf8)) ?? ""
    }
}
