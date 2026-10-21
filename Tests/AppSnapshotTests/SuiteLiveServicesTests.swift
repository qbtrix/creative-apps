// SuiteLiveServicesTests.swift: SuiteServices.live over a temp support
// folder (suite-contracts SC-5b, SC-5c). It is not a preview; recents is
// live and writes recents.json there, creating and home are live (HM-2a),
// preferences is live over preferences.json (onboarding OB-9), onboarding is
// SuiteOnboarding (OB-12), pasteboard is SuitePasteboardCoding (clipboard-interop CB-4); each other
// slotted member is pending with its "<What> isn't available yet."
// sentence, and each throwing one throws notAvailable with that sentence.
// `animations` and `updates` are the fakes until `with(animations:updates:)`
// swaps them. macOS only (SuiteShell).
import Foundation
import SuiteModel
import SuiteShell
import Testing

@Suite(.timeLimit(.minutes(1))) struct SuiteLiveServicesTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeLive() -> (services: SuiteServices, support: String) {
        let support = FileManager.default.temporaryDirectory
            .appendingPathComponent("SuiteLiveServicesTests-\(UUID().uuidString)").path
        return (SuiteServices.live(support: support, app: .launcher, arguments: []), support)
    }

    private func ref(_ name: String) -> SuiteDocumentRef {
        let path = "/tmp/Documents/" + name
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                                type: .designDocument, displayName: name)
    }

    /// The error a not-live member throws: notAvailable with its feature's sentence.
    private func reason(_ member: String) -> SuiteError {
        .notAvailable(SuiteServices.notConnected(member) ?? "no feature for \(member)")
    }

    @Test func liveIsNotAPreview() {
        #expect(makeLive().services.isPreview == false)
    }

    @Test func recentsNotesAndListsThroughTheSupportFolder() async throws {
        let (s, support) = makeLive()
        try await s.recents.note(ref("Logo.design"), event: .opened, at: now, thumbnail: nil)
        let names = try await s.recents.list().items.map(\.ref.displayName)
        #expect(names == ["Logo.design"])
        let onDisk = try FileStore(folder: support).read("recents.json", as: RecentsList.self)
        #expect(onDisk.value?.items.map(\.ref.displayName) == ["Logo.design"])
        #expect(onDisk.revision == 1)
        #expect(s.pending["recents"] == nil)
    }

    @Test func preferencesLoadDefaultsAndSaveThroughTheSupportFolder() async throws {
        let (s, support) = makeLive()
        #expect(s.pending["preferences"] == nil)
        var p = try await s.preferences.load()
        #expect(p == SuitePreferences())
        p.onboardingDoneVersion = 1
        #expect(try await s.preferences.save(p).revision == 1)
        let onDisk = try FileStore(folder: support).read("preferences.json", as: SuitePreferences.self)
        #expect(onDisk.value?.onboardingDoneVersion == 1 && onDisk.revision == 1)
    }

    @Test func everyOtherSlottedMemberIsPendingWithItsFeature() {
        let pending = makeLive().services.pending
        var expected = SuiteServices.slotFeatures.mapValues(SuiteIdentity.notConnected)
        let live = ["recents", "creating", "home", "switching", "sending", "receiving", "preferences", "onboarding",
                    "pasteboard"]
        for member in live { expected[member] = nil }
        #expect(pending == expected)
        #expect(pending.count == 6)
        #expect(pending["thumbnails"] == "Opening recent work isn't available yet.")
        #expect(pending["home"] == nil)
        #expect(pending["creating"] == nil)
        #expect(pending["onboarding"] == nil)
        #expect(pending["roundTrips"] == "Editing in Photo and back isn't available yet.")
        #expect(pending["pasteboard"] == nil)
        #expect(pending["assets"] == "The shared asset library isn't available yet.")
        #expect(pending["linking"] == "Linking assets between apps isn't available yet.")
        #expect(pending["preferences"] == nil)
        #expect(pending["settings"] == "The Settings window isn't available yet.")
    }

    @Test func everySlottedMemberIsLiveOrPending() {
        let pending = makeLive().services.pending
        let members: Set<String> = ["switching", "recents", "creating", "routing", "sending", "receiving",
                                    "roundTrips", "pasteboard", "assets", "linking", "preferences", "settings",
                                    "onboarding", "thumbnails", "home"]
        #expect(Set(SuiteServices.slotFeatures.keys) == members)
        let live: Set<String> = ["recents", "creating", "home", "switching", "sending", "receiving", "preferences",
                                  "onboarding", "pasteboard"]
        #expect(Set(pending.keys).union(live) == members)
    }

    @Test func throwingMembersNotLiveThrowTheirReason() async throws {
        let s = makeLive().services
        let logo = ref("Logo.design")
        await #expect(throws: reason("thumbnails")) { _ = try await s.thumbnails.publish(png: Data(), for: logo) }
        await #expect(throws: reason("roundTrips")) { try await s.roundTrips.cancel(session: "r1") }
        await #expect(throws: reason("assets")) { _ = try await s.assets.index() }
        await #expect(throws: reason("settings")) { try await s.settings.open(.general, from: .launcher) }
    }

    @Test func pureMembersAreTheReferenceFakes() throws {
        let s = makeLive().services
        #expect(try s.routing.route(fileName: "Logo.design") == .design)
        #expect(s.creating.tiles(missing: []).allSatisfy { $0.disabledReason == nil })
        #expect(s.onboarding.pages.count == 3)
        #expect(s.pasteboard is SuitePasteboardCoding)
        #expect(s.linking is FakeLinking)
    }

    @Test func onboardingIsTheLiveTourAndShowsUntilDone() {
        let s = makeLive().services
        #expect(s.pending["onboarding"] == nil)
        #expect(s.onboarding is SuiteOnboarding)
        #expect(s.onboarding.shouldShow(SuitePreferences(), version: 1))
        var done = SuitePreferences()
        done.onboardingDoneVersion = 1
        #expect(!s.onboarding.shouldShow(done, version: 1))
    }

    @Test func animationsAndUpdatesAreFakesUntilSwapped() async throws {
        let s = makeLive().services
        #expect(s.animations is FakeAnimationSource)
        #expect(s.updates is FakeUpdates)
        #expect(s.pending["animations"] == nil)
        #expect(s.pending["updates"] == nil)
        #expect(try await s.updates.check(current: SuiteVersion(1, 0, 0)) == nil)
        let swapped = s.with(animations: FakeAnimationSource(unavailable: "Swapped animations."),
                             updates: FakeUpdates(unavailable: "Swapped updates."))
        let logo = ref("Logo.design")
        await #expect(throws: SuiteError.notAvailable("Swapped animations.")) {
            _ = try await swapped.animations.summary(of: logo)
        }
        await #expect(throws: SuiteError.notAvailable("Swapped updates.")) {
            _ = try await swapped.updates.check(current: SuiteVersion(1, 0, 0))
        }
        #expect(swapped.pending == s.pending)
    }
}
