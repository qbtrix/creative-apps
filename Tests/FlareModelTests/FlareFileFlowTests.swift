// FlareFileFlowTests.swift: MFL, Flare's file-flow Model walk (file-flow
// FL-1 written, FL-3 turns it on). Flare as a FileFlowTarget and a
// SuiteDocumentHost: it names itself "flare", opens a dropped .flare, hands
// a .halo to Halo, refuses an SVG with "Flare can't import SVG yet." until
// SVG import (E11), and accepts open and new hand-offs. Runs on Linux and
// macOS.
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

/// A hand-off from Library to Flare for `path`.
private func handOff(_ verb: HandOffVerb, path: String = "/w/Bounce.flare",
                     type: SuiteTypeID = .flareAnimation) -> HandOff {
    let name = path.split(separator: "/").last.map(String.init) ?? path
    let ref = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .library,
                               type: type, displayName: name)
    return HandOff(id: HandOff.newID(), from: .library, to: .flare, verb: verb, documents: [ref],
                   createdAt: Date(timeIntervalSince1970: 0))
}

/// Runs Clear Menu the way the shared command does, through the protocol.
private func clearThroughFileFlow<T: FileFlowTarget>(_ target: inout T) throws { try target.clearRecent() }

/// The FL-1 stubs, on today: what the adapter answers before FL-3 writes the bodies.
/// FL-3 replaces the refusal and not-built checks with the walk below.
@Suite struct FlareFileFlowStubTests {
    @Test func flareNamesItselfAndPlacesNothingYet() {
        let workspace = FlareWorkspace(services: .fake())
        #expect(workspace.appID == "flare")
        #expect(workspace.placesExtensions.isEmpty)
    }

    @Test func hasDocumentFollowsTheDocument() {
        #expect(!FlareWorkspace(services: .fake()).hasDocument)
        #expect(opened().hasDocument)
    }

    @Test func noSuiteRecentsAndNoOpenInYet() {
        let workspace = opened()
        #expect(workspace.recentFiles.isEmpty)
        #expect(workspace.openInApps.isEmpty)
        #expect(workspace.openInHelp == "Open In isn't built yet.")
        #expect(workspace.readers(ofExtension: "flare").isEmpty)
    }

    @Test func everyHandOffIsRefusedWithTheReason() async throws {
        let workspace = opened()
        let reason = SuiteError.notAvailable("Flare can't take files from other apps yet.")
        for verb in [HandOffVerb.open, .new, .place, .edit, .importAnimation] {
            #expect(await workspace.refusal(for: handOff(verb)) == reason)
        }
        await #expect(throws: reason) { _ = try await workspace.accept(handOff(.open)) }
    }

    @Test func openRecentOpenInAndDropThrowNotBuilt() {
        var workspace = opened()
        let before = workspace.document
        let notBuilt = { (id: String) in CatalogError.notBuilt(id: id, feature: "file-flow") }
        #expect(throws: notBuilt("file.open-recent")) { try workspace.openRecent("abc") }
        #expect(throws: notBuilt("file.open-in")) { try workspace.openIn("halo") }
        #expect(throws: notBuilt("file.drop")) { try workspace.perform([.open(path: "/w/Bounce.flare")]) }
        #expect(workspace.document == before)
    }

    @Test func clearMenuStillEmptiesFlaresOwnList() throws {
        var workspace = FlareWorkspace(services: .fake())
        workspace.noteRecent("/w/Bounce.flare")
        try clearThroughFileFlow(&workspace)
        #expect(workspace.recent.isEmpty)
    }
}

/// MFL, the behaviour FL-3 turns on.
@Suite(.disabled("waits on FL-3")) struct FlareFileFlowTests {
    /// The drop rule for one path into `target`.
    private func plan(_ target: FlareWorkspace, _ path: String) -> [DropAction] {
        DropPlan.plan([path], into: target.appID, hasDocument: target.hasDocument,
                      places: target.placesExtensions, readers: { target.readers(ofExtension: $0) })
    }

    @Test func aFlareOpensAndAHaloGoesToHalo() {
        let workspace = opened()
        #expect(plan(workspace, "/w/Bounce.flare") == [.open(path: "/w/Bounce.flare")])
        #expect(plan(workspace, "/w/Intro.halo") == [.handOff(path: "/w/Intro.halo", app: "halo")])
    }

    @Test func anSVGIsRefusedUntilSVGImport() throws {
        var workspace = opened()
        let before = workspace.document
        #expect(plan(workspace, "/w/logo.svg") == [.refuse(path: "/w/logo.svg", reason: FlareWorkspace.svgRefusal)])
        try workspace.perform(plan(workspace, "/w/logo.svg"))
        #expect(workspace.document == before)
        #expect(workspace.undoActionName == nil)
    }

    @Test func openInOffersHaloForAFlare() {
        let workspace = opened()
        #expect(workspace.openInApps.contains("halo"))
        #expect(!workspace.openInApps.contains("flare"))
    }

    @Test func hostAcceptsOpenAndNewAndRefusesPlace() async {
        let workspace = opened()
        for verb in [HandOffVerb.open, .new] {
            #expect(await workspace.refusal(for: handOff(verb)) == nil)
        }
        let place = handOff(.place, path: "/w/logo.svg", type: .svg)
        #expect(await workspace.refusal(for: place) == .notAvailable(FlareWorkspace.svgRefusal))
    }

    @Test func clearRecentEmptiesTheSuiteList() throws {
        var workspace = FlareWorkspace(services: .fake())
        workspace.noteRecent("/w/Bounce.flare")
        try clearThroughFileFlow(&workspace)
        #expect(workspace.recentFiles.isEmpty)
    }
}
