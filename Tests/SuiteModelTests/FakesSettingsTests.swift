// FakesSettingsTests.swift: the animation, preferences, settings-route,
// onboarding and update fakes behave as blueprint 5.5 states: a stale
// preferences save is refused, onboarding's focus orders home, a forged
// update signature isn't installed, a refusing app postpones the update, and
// `unavailable:` turns every throwing call into that sentence.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct FakesSettingsTests {
    let reason = "Not connected yet (suite-contracts)."

    func error(_ body: () async throws -> Void) async -> SuiteError? {
        do { try await body(); return nil } catch { return error as? SuiteError }
    }

    func offer(_ version: SuiteVersion, signature: String) -> UpdateOffer {
        UpdateOffer(version: version, notes: "Fixes", url: "https://example.org/a.zip", byteCount: 10,
                    signature: signature, minimumSystem: "26.0")
    }

    func bounce(fileID: String? = nil) -> SuiteDocumentRef {
        let path = "/tmp/Documents/Bounce.flare"
        return SuiteDocumentRef(path: path, fileID: fileID ?? SuiteDocumentRef.fileID(forPath: path), app: .flare,
                                type: .flareAnimation, displayName: "Bounce.flare")
    }

    @Test func aStalePreferencesRevisionIsRefused() async throws {
        let prefs = FakePreferences()
        var changes = await prefs.changes().makeAsyncIterator()
        let loaded = try await prefs.load()
        var edit = loaded
        edit.units = .pixels
        let saved = try await prefs.save(edit)
        #expect(saved.revision == loaded.revision + 1)
        #expect(await changes.next() == saved.revision)
        #expect(try await prefs.load().units == .pixels)
        #expect(await error { _ = try await prefs.save(loaded) } == .staleRevision)
        #expect(try await prefs.load() == saved)
    }

    @Test func onboardingFocusOrdersHome() {
        let flow = FakeOnboarding()
        let fresh = SuitePreferences()
        #expect(flow.pages.map(\.id) == ["apps", "focus", "start"])
        #expect(flow.pages.map(\.choices) == [[], OnboardingFocus.allCases, []])
        #expect(flow.shouldShow(fresh, version: 1))
        let photos = flow.finishing(fresh, focus: .photos, version: 1)
        #expect(photos.homeOrder == [.library, .photo, .flare, .design, .halo])
        #expect(photos.onboardingDoneVersion == 1)
        #expect(!flow.shouldShow(photos, version: 1))
        #expect(flow.finishing(fresh, focus: .animation, version: 1).homeOrder == [.flare, .halo, .design, .photo, .library])
        #expect(flow.finishing(fresh, focus: .design, version: 1).homeOrder == [.design, .flare, .photo, .library, .halo])
        #expect(flow.finishing(fresh, focus: .motion, version: 1).homeOrder == [.halo, .flare, .design, .photo, .library])
        #expect(flow.finishing(fresh, focus: nil, version: 1).homeOrder == SuiteApp.apps)
    }

    @Test func aForgedUpdateSignatureIsNotVerified() async throws {
        let good = offer(SuiteVersion(1, 2, 0), signature: "good")
        let feed = try JSONEncoder().encode([offer(SuiteVersion(1, 1, 0), signature: "good"), good])
        let updates = FakeUpdates(feed: feed, validSignatures: ["good"])
        #expect(try await updates.check(current: SuiteVersion(1, 0, 0)) == good)
        #expect(try await updates.check(current: SuiteVersion(1, 2, 0)) == nil)
        let forged = offer(SuiteVersion(1, 2, 0), signature: "forged")
        #expect(await error { _ = try await updates.download(forged) } == .updateNotVerified)
        let zip = try await updates.download(good)
        #expect(zip == "/tmp/AfterGlow-1.2.0.zip")
        try await updates.install(zipAt: zip)
        #expect(await updates.installed == [zip])
    }

    @Test func aRefusingAppPostponesTheUpdate() async {
        let updates = FakeUpdates(validSignatures: ["good"], refusesQuit: .design)
        #expect(await error { try await updates.install(zipAt: "/tmp/AfterGlow-1.2.0.zip") } == .updatePostponed(.design))
        #expect(await updates.installed.isEmpty)
    }

    @Test func animationSourceAndSettingsRoute() async throws {
        let ref = bounce()
        let summary = AnimationSummary(name: "Bounce", width: 1920, height: 1080, framesPerSecond: 24, frameCount: 48,
                                       sceneNames: ["Main"])
        #expect(try await FakeAnimationSource(summaries: [ref.fileID: summary]).summary(of: ref) == summary)
        #expect(await error { _ = try await FakeAnimationSource().summary(of: ref) } == .fileMissing(name: "Bounce.flare"))

        let route = FakeSettingsRoute()
        try await route.open(.app(.flare), from: .flare)
        try await route.open(.general, from: .photo)
        #expect(await route.opened == [.app(.flare), .general])
    }

    @Test func unavailableThrowsItsReason() async {
        let off = SuiteError.notAvailable(reason)
        #expect(await error { _ = try await FakeAnimationSource(unavailable: reason).summary(of: bounce()) } == off)
        let prefs = FakePreferences(unavailable: reason)
        #expect(await error { _ = try await prefs.load() } == off)
        #expect(await error { _ = try await prefs.save(SuitePreferences()) } == off)
        let route = FakeSettingsRoute(unavailable: reason)
        #expect(await error { try await route.open(.general, from: .photo) } == off)
        #expect(await route.opened.isEmpty)
        let updates = FakeUpdates(validSignatures: ["good"], unavailable: reason)
        #expect(await error { _ = try await updates.check(current: SuiteVersion(1, 0, 0)) } == off)
        #expect(await error { _ = try await updates.download(offer(SuiteVersion(1, 2, 0), signature: "good")) } == off)
        #expect(await error { try await updates.install(zipAt: "/tmp/a.zip") } == off)
    }
}
