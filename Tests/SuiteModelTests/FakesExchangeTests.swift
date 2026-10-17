// FakesExchangeTests.swift: the exchange fakes behave as blueprint 5.5
// states: a damaged envelope falls back to SVG then PNG, Flare refuses
// images, an empty pasteboard has nothing to paste, a dropped file gets the
// one identity rule and dedupes against recents (packet correction 3), a
// round trip refuses a missing original, links report their status, and
// `unavailable:` turns every throwing call into that sentence.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct FakesExchangeTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let reason = "Not connected yet (suite-contracts)."
    let pasteboard = FakePasteboard()
    let damaged = TypedData(type: .assetEnvelope, data: Data("{not json".utf8))
    let svg = TypedData(type: .svg, data: Data("<svg/>".utf8))
    let png = TypedData(type: .png, data: Data([0x89, 0x50, 0x4E, 0x47]))

    func ref(_ path: String, _ app: SuiteApp = .photo, _ type: SuiteTypeID = .png) -> SuiteDocumentRef {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: app, type: type, displayName: name)
    }

    func error(_ body: () async throws -> Void) async -> SuiteError? {
        do { try await body(); return nil } catch { return error as? SuiteError }
    }

    @Test func aDamagedEnvelopeFallsBackToSVGThenPNG() {
        #expect(pasteboard.bestItem(from: [damaged, png, svg], for: .design) == .vector(svg: "<svg/>", name: "Pasted art"))
        #expect(pasteboard.bestItem(from: [damaged, png], for: .design) == .image(png: png.data, pixelWidth: 0, pixelHeight: 0))
        let text = TypedData(type: .plainText, data: Data("hi".utf8))
        #expect(pasteboard.bestItem(from: [text, damaged, png], for: .photo) == .image(png: png.data, pixelWidth: 0, pixelHeight: 0))
        #expect(pasteboard.bestItem(from: [damaged, text], for: .design) == .text("hi"))
    }

    @Test func anEnvelopeRoundTripsAheadOfItsSVG() {
        let e = AssetEnvelope(name: "Star", kind: .vector, from: .design, svg: "<svg/>")
        let reps = pasteboard.representations(of: .envelope(e))
        #expect(reps.map(\.type) == [.assetEnvelope, .svg])
        #expect(pasteboard.bestItem(from: reps, for: .flare) == .envelope(e))
    }

    @Test func flareRefusesImagesAndAnEmptyPasteboardHasNothing() {
        let refusal = pasteboard.pasteRefusal(for: [png], in: .flare)
        #expect(refusal == .cannotPaste(app: .flare, kind: "images"))
        #expect(refusal?.message == "Flare can't paste images yet.")
        #expect(pasteboard.pasteRefusal(for: [], in: .design) == .nothingToPaste)
        #expect(pasteboard.pasteRefusal(for: [png], in: .design) == nil)
    }

    @Test func aDroppedFileGetsTheIdentityRuleAndDedupesAgainstRecents() async throws {
        let path = "/Users/me/Documents/Logo.design"
        let drop = TypedData(type: .fileURL, data: Data("file://\(path)".utf8))
        guard case .files(let refs)? = pasteboard.bestItem(from: [drop], for: .launcher), let dropped = refs.first else {
            Issue.record("the drop gave no file"); return
        }
        #expect(dropped.fileID == SuiteDocumentRef.fileID(forPath: path))
        #expect(dropped.path == path)
        #expect(dropped.app == .design)
        #expect(dropped.type == .designDocument)

        let recents = FakeRecents()
        try await recents.note(ref(path, .design, .designDocument), event: .opened, at: now - 60, thumbnail: nil)
        try await recents.note(dropped, event: .opened, at: now, thumbnail: nil)
        #expect(try await recents.list().items.count == 1)
    }

    @Test func roundTripsRefuseAMissingOriginal() async throws {
        let gone = ref("/Users/me/Pictures/IMG_0002.png")
        let trips = FakeRoundTrips(missingOriginals: [gone.fileID])
        let source = RoundTripSource(catalogPhotoID: "p2", original: gone)
        #expect(await error { _ = try await trips.begin(source, id: "s1", at: now) } == .originalMissing(name: "IMG_0002"))

        let here = RoundTripSource(catalogPhotoID: "p3", original: ref("/Users/me/Pictures/IMG_0003.png"))
        let open = try await trips.begin(here, id: "s2", at: now)
        #expect(open.title == "IMG_0003 (Library edit)")
        #expect(await error { _ = try await trips.returned(session: "s2", as: here.original) } == .notAvailable("Nothing to bring back yet."))
        let flat = ref("/Users/me/Pictures/IMG_0003 edit.png")
        _ = try await trips.photoSaved(session: "s2", flattened: flat, layered: flat)
        #expect(try await trips.returned(session: "s2", as: flat).state == .returned(flat))
    }

    @Test func linkingReportsUpdateAvailableAndMissing() async throws {
        let assets = FakeAssets()
        let star = try await assets.add(AssetDraft(kind: .vector, name: "Star", payload: Data("<svg/>".utf8), payloadExtension: "svg"),
                                        id: "a1", at: now)
        let linking = FakeLinking()
        let link = linking.link(to: star)
        #expect(linking.status(of: link, in: try await assets.index()) == .current)

        var changes = await assets.changes().makeAsyncIterator()
        let newer = try await assets.update("a1", payload: Data("<svg>2</svg>".utf8), color: nil, at: now + 1)
        #expect(await changes.next() == 2)
        #expect(newer.revision == 2)
        #expect(newer.payload == "assets/a1/2.svg")
        #expect(try await assets.payload(of: newer) == Data("<svg>2</svg>".utf8))
        let index = try await assets.index()
        #expect(linking.status(of: link, in: index) == .updateAvailable(revision: 2))
        #expect(linking.updated(link, in: index)?.placedRevision == 2)

        try await assets.remove("a1")
        #expect(linking.status(of: link, in: try await assets.index()) == .missing)
    }

    @Test func unavailableFakesThrowThatSentence() async {
        let trips = FakeRoundTrips(unavailable: reason)
        let source = RoundTripSource(catalogPhotoID: "p1", original: ref("/Users/me/Pictures/IMG_0001.png"))
        #expect(await error { _ = try await trips.begin(source, id: "s1", at: now) } == .notAvailable(reason))
        let assets = FakeAssets(unavailable: reason)
        #expect(await error { _ = try await assets.index() } == .notAvailable(reason))
        #expect(await error { _ = try await assets.add(AssetDraft(kind: .color, name: "Red"), id: "c1", at: now) } == .notAvailable(reason))
        #expect(await error { try await assets.remove("c1") } == .notAvailable(reason))
        #expect(SuiteError.notAvailable(reason).message == reason)
    }
}
