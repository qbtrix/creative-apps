// ContractShapeMoreTests.swift: one minimal conformer per tier-2 and tier-3
// contract (blueprint suite.md 5.2) calls every requirement once, so a
// signature that drifts stops this file compiling, and the changes() streams
// of AssetLibrary and PreferencesStoring must yield.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

private let moreDate = Date(timeIntervalSince1970: 1_000)
private let moreRef = SuiteDocumentRef(path: "/tmp/IMG_0002.jpg", fileID: "f1", app: .photo, type: .jpeg, displayName: "IMG_0002")
private let moreColor = SuiteColorValue(space: .displayP3, red: 1, green: 0.5, blue: 0)
private let moreAsset = SuiteAsset(id: "a1", kind: .color, name: "Ember", color: moreColor, modifiedAt: moreDate)
private let moreOffer = UpdateOffer(version: SuiteVersion(1, 1, 0), notes: "", url: "https://example.com/a.zip",
                                    byteCount: 1, signature: "", minimumSystem: "26.0")

private func moreSession(_ id: String, _ state: RoundTripState) -> RoundTripSession {
    RoundTripSession(id: id, source: RoundTripSource(catalogPhotoID: "p1", original: moreRef),
                     title: "IMG_0002 (Library edit)", state: state, startedAt: moreDate)
}

private func oneYield() -> AsyncStream<Int> { AsyncStream { $0.yield(1); $0.finish() } }

private struct MoreShapeRoundTrips: RoundTripEditing {
    func begin(_ source: RoundTripSource, id: String, at date: Date) async throws(SuiteError) -> RoundTripSession { moreSession(id, .open) }
    func photoSaved(session id: String, flattened: SuiteDocumentRef, layered: SuiteDocumentRef) async throws(SuiteError) -> RoundTripSession {
        moreSession(id, .saved(flattened: flattened, layered: layered))
    }
    func returned(session id: String, as ref: SuiteDocumentRef) async throws(SuiteError) -> RoundTripSession { moreSession(id, .returned(ref)) }
    func cancel(session id: String) async throws(SuiteError) { if id.isEmpty { throw .cancelled } }
    func session(_ id: String) async -> RoundTripSession? { moreSession(id, .open) }
}

private struct MoreShapePasteboard: PasteboardCoding {
    func representations(of item: SuiteClipItem) -> [TypedData] { [TypedData(type: .plainText, data: Data("x".utf8))] }
    func bestItem(from offered: [TypedData], for app: SuiteApp) -> SuiteClipItem? { offered.isEmpty ? nil : .text("x") }
    func pasteRefusal(for offered: [TypedData], in app: SuiteApp) -> SuiteError? { offered.isEmpty ? .nothingToPaste : nil }
}

private struct MoreShapeAssets: AssetLibrary {
    func index() async throws(SuiteError) -> AssetIndex { AssetIndex(revision: 1, assets: [moreAsset]) }
    func add(_ draft: AssetDraft, id: String, at date: Date) async throws(SuiteError) -> SuiteAsset {
        SuiteAsset(id: id, kind: draft.kind, name: draft.name, color: draft.color, modifiedAt: date)
    }
    func update(_ id: String, payload: Data?, color: SuiteColorValue?, at date: Date) async throws(SuiteError) -> SuiteAsset {
        var a = moreAsset; a.revision += 1; a.modifiedAt = date; return a
    }
    func remove(_ id: String) async throws(SuiteError) { if id.isEmpty { throw .linkMissing } }
    func payload(of asset: SuiteAsset) async throws(SuiteError) -> Data { Data("<svg/>".utf8) }
    func assets(fromFileID fileID: String) async throws(SuiteError) -> [SuiteAsset] { [moreAsset] }
    func changes() async -> AsyncStream<Int> { oneYield() }
}

private struct MoreShapeLinking: AssetLinking {
    func link(to asset: SuiteAsset) -> AssetLink { AssetLink(assetID: asset.id, kind: asset.kind, placedRevision: asset.revision) }
    func status(of link: AssetLink, in index: AssetIndex) -> LinkStatus { .current }
    func updated(_ link: AssetLink, in index: AssetIndex) -> AssetLink? { nil }
}

private struct MoreShapeAnimation: AnimationSourceReading {
    func summary(of ref: SuiteDocumentRef) async throws(SuiteError) -> AnimationSummary {
        AnimationSummary(name: ref.displayName, width: 640, height: 480, framesPerSecond: 24, frameCount: 48, sceneNames: ["Scene 1"])
    }
}

private struct MoreShapePreferences: PreferencesStoring {
    func load() async throws(SuiteError) -> SuitePreferences { SuitePreferences() }
    func save(_ preferences: SuitePreferences) async throws(SuiteError) -> SuitePreferences {
        var p = preferences; p.revision += 1; return p
    }
    func changes() async -> AsyncStream<Int> { oneYield() }
}

private struct MoreShapeSettingsRoute: SettingsRouting {
    func open(_ pane: SettingsPane, from app: SuiteApp) async throws(SuiteError) {}
}

private struct MoreShapeOnboarding: OnboardingFlowing {
    var pages: [OnboardingPage] { [OnboardingPage(id: "welcome", title: "Welcome", body: "Hi")] }
    func shouldShow(_ preferences: SuitePreferences, version: Int) -> Bool { (preferences.onboardingDoneVersion ?? 0) < version }
    func finishing(_ preferences: SuitePreferences, focus: OnboardingFocus?, version: Int) -> SuitePreferences {
        var p = preferences; p.onboardingDoneVersion = version; return p
    }
}

private struct MoreShapeUpdates: UpdateChecking {
    func check(current: SuiteVersion) async throws(SuiteError) -> UpdateOffer? { current < moreOffer.version ? moreOffer : nil }
    func download(_ offer: UpdateOffer) async throws(SuiteError) -> String { "/tmp/AfterGlow.zip" }
    func install(zipAt path: String) async throws(SuiteError) { throw .updatePostponed(.flare) }
}

private func firstValue(_ stream: AsyncStream<Int>) async -> Int? {
    for await value in stream { return value }
    return nil
}

@Suite struct ContractShapeMoreTests {
    @Test func everyRequirementIsCallable() async {
        do throws(SuiteError) {
            let trips = MoreShapeRoundTrips()
            #expect(try await trips.begin(RoundTripSource(catalogPhotoID: "p1", original: moreRef), id: "r1", at: moreDate).state == .open)
            #expect(try await trips.photoSaved(session: "r1", flattened: moreRef, layered: moreRef).state == .saved(flattened: moreRef, layered: moreRef))
            #expect(try await trips.returned(session: "r1", as: moreRef).state == .returned(moreRef))
            try await trips.cancel(session: "r1")
            #expect(await trips.session("r1")?.id == "r1")

            let board = MoreShapePasteboard()
            let reps = board.representations(of: .text("x"))
            #expect(board.bestItem(from: reps, for: .design) == .text("x"))
            #expect(board.pasteRefusal(for: [], in: .flare) == .nothingToPaste)

            let assets = MoreShapeAssets()
            #expect(try await assets.index().revision == 1)
            #expect(try await assets.add(AssetDraft(kind: .color, name: "Ember", color: moreColor), id: "a2", at: moreDate).id == "a2")
            #expect(try await assets.update("a1", payload: nil, color: moreColor, at: moreDate).revision == 2)
            try await assets.remove("a1")
            #expect(try await assets.payload(of: moreAsset).isEmpty == false)
            #expect(try await assets.assets(fromFileID: "f1") == [moreAsset])

            let linking = MoreShapeLinking()
            let link = linking.link(to: moreAsset)
            #expect(linking.status(of: link, in: AssetIndex()) == .current)
            #expect(linking.updated(link, in: AssetIndex()) == nil)

            #expect(try await MoreShapeAnimation().summary(of: moreRef).frameCount == 48)

            let prefs = MoreShapePreferences()
            #expect(try await prefs.save(try await prefs.load()).revision == 1)

            try await MoreShapeSettingsRoute().open(.app(.halo), from: .design)

            let onboarding = MoreShapeOnboarding()
            #expect(onboarding.pages.count == 1)
            #expect(onboarding.shouldShow(SuitePreferences(), version: 1))
            #expect(onboarding.finishing(SuitePreferences(), focus: .photos, version: 1).onboardingDoneVersion == 1)

            let updates = MoreShapeUpdates()
            let offer = try await updates.check(current: SuiteVersion(1, 0, 0))
            #expect(offer == moreOffer)
            #expect(try await updates.download(moreOffer) == "/tmp/AfterGlow.zip")
        } catch {
            Issue.record("unexpected \(error)")
        }
    }

    @Test func installRefusalIsTypedSuiteError() async {
        do throws(SuiteError) {
            try await MoreShapeUpdates().install(zipAt: "/tmp/AfterGlow.zip")
            Issue.record("install should be postponed")
        } catch {
            #expect(error == .updatePostponed(.flare))
        }
    }

    @Test func assetAndPreferenceStreamsYield() async {
        #expect(await firstValue(await MoreShapeAssets().changes()) == 1)
        #expect(await firstValue(await MoreShapePreferences().changes()) == 1)
    }
}
