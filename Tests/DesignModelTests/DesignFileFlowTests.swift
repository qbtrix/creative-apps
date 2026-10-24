// DesignFileFlowTests.swift (file-flow DF-1, on at DF-3, MDF): Design's document hands another app's file
// to that app and leaves itself unchanged, opens its own, lists only Design's recents newest first,
// keeps Open In off with its reason, refuses a place until S20 and takes a new document. Linux-safe.
import Foundation
import Testing
import DesignModel
import SuiteKernel
import SuiteModel

@Suite struct DesignFileFlowTests {
    static func document() -> DesignDocument {
        DesignDocument(pages: [DesignPage(id: "p1", name: "Page 1", frameWidth: 1440, frameHeight: 1024)])
    }

    static var catalog: CommandCatalog<DesignDocument>? {
        try? CommandCatalog(app: "design", FileFlowCommands.specs(DesignDocument.self), history: { _ in History<Int>() })
    }

    static func handOff(_ verb: HandOffVerb) -> HandOff {
        HandOff(id: "df-1", from: .launcher, to: .design, verb: verb, createdAt: Date(timeIntervalSince1970: 0))
    }

    @Test(.disabled("DF-3 turns on")) func haloDropIsHandedOffAndChangesNothing() throws {
        let catalog = try #require(Self.catalog)
        var document = Self.document()
        let before = document
        let outcome = try catalog.run("file.drop", params: .object(["paths": .array([.string("/w/Intro.halo")])]),
                                      on: &document)
        #expect(try outcome.result.decode([DropAction].self) == [.handOff(path: "/w/Intro.halo", app: "halo")])
        #expect(document == before)
    }

    @Test(.disabled("DF-3 turns on")) func designDropOpens() throws {
        let catalog = try #require(Self.catalog)
        var document = Self.document()
        let outcome = try catalog.run("file.drop", params: .object(["paths": .array([.string("/w/Logo.design")])]),
                                      on: &document)
        #expect(try outcome.result.decode([DropAction].self) == [.open(path: "/w/Logo.design")])
    }

    @Test(.disabled("DF-3 turns on")) func recentFilesAreOnlyDesignsNewestFirst() throws {
        let catalog = try #require(Self.catalog)
        var document = Self.document()
        let listed = try catalog.run("file.recent", params: .object([:]), on: &document).result.decode([RecentFileEntry].self)
        #expect(!listed.isEmpty)
        #expect(listed.allSatisfy { $0.app == "design" })
        #expect(listed.map(\.lastUsed) == listed.map(\.lastUsed).sorted(by: >))
    }

    @Test func openInIsOffWithItsReason() throws {
        let catalog = try #require(Self.catalog)
        let document = Self.document()
        #expect(document.openInApps.isEmpty)
        #expect(catalog.availability("file.open-in", on: document).why == "No other app opens Design Document files.")
    }

    @Test(.disabled("DF-3 turns on")) func placeIsRefusedUntilS20() async {
        let document = Self.document()
        #expect(await document.refusal(for: Self.handOff(.place)) == .notAvailable("Design can't place files yet."))
        #expect(document.placesExtensions.isEmpty)
    }

    @Test(.disabled("DF-3 turns on")) func newIsAccepted() async throws {
        let document = Self.document()
        #expect(await document.refusal(for: Self.handOff(.new)) == nil)
        #expect(try await document.accept(Self.handOff(.new)) != .cancelled)
    }
}
