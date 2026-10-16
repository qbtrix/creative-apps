// SuiteServicesTests.swift: SuiteServices (SC-4b). `.fake` is a preview with
// nothing pending, `with(animations:updates:)` swaps only those two members,
// and `slotFeatures` names a feature for each of the 15 slotted members.
import SuiteModel
import Testing

@Suite struct SuiteServicesTests {
    static let slotted = ["switching", "recents", "creating", "routing", "sending", "receiving", "roundTrips",
                          "pasteboard", "assets", "linking", "preferences", "settings", "onboarding", "thumbnails", "home"]

    @Test func fakeIsAPreviewWithNothingPending() {
        let s = SuiteServices.fake()
        #expect(s.isPreview)
        #expect(s.pending.isEmpty)
    }

    @Test func fakeSharesOneSwitchingBetweenSendingAndReceiving() async throws {
        let s = SuiteServices.fake(running: [.design])
        #expect(s.sending as AnyObject === s.receiving as AnyObject)
        #expect(await s.switching.runState(of: .design) == .running(windows: 1))
    }

    @Test func withSwapsOnlyAnimationsAndUpdates() async {
        let s = SuiteServices.fake()
        let updates = FakeUpdates()
        let animations = FakeAnimationSource(unavailable: "Halo supplies this.")
        let swapped = s.with(animations: animations, updates: updates)
        #expect(swapped.updates as AnyObject === updates)
        #expect(swapped.updates as AnyObject !== s.updates as AnyObject)
        await #expect(throws: SuiteError.notAvailable("Halo supplies this.")) {
            _ = try await swapped.animations.summary(of: SuiteDocumentRef(path: "/a.flare", fileID: "x", app: .flare,
                                                                            type: .flareAnimation, displayName: "a.flare"))
        }
        let kept: [(any Sendable, any Sendable)] = [
            (s.switching, swapped.switching), (s.recents, swapped.recents), (s.sending, swapped.sending),
            (s.receiving, swapped.receiving), (s.roundTrips, swapped.roundTrips), (s.assets, swapped.assets),
            (s.preferences, swapped.preferences), (s.settings, swapped.settings), (s.thumbnails, swapped.thumbnails),
        ]
        for (a, b) in kept { #expect(a as AnyObject === b as AnyObject) }
        #expect(swapped.isPreview && swapped.pending.isEmpty)
        let none = s.with()
        #expect(none.updates as AnyObject === s.updates as AnyObject)
    }

    @Test func slotFeaturesNamesAFeatureForEachSlottedMember() {
        #expect(Set(SuiteServices.slotFeatures.keys) == Set(Self.slotted))
        #expect(SuiteServices.slotFeatures.count == 15)
        #expect(SuiteServices.slotFeatures["animations"] == nil && SuiteServices.slotFeatures["updates"] == nil)
        for member in Self.slotted {
            let feature = SuiteServices.slotFeatures[member] ?? ""
            #expect(!feature.isEmpty && feature == feature.lowercased(), "\(member)")
        }
        #expect(SuiteServices.slotFeatures["sending"] == "switching")
        #expect(SuiteServices.notConnected("pasteboard") == "Copy and paste between apps isn't available yet.")
        #expect(SuiteServices.notConnected("updates") == nil)
    }

    /// #1457: a not-connected reason is a plain sentence; no feature slug,
    /// hyphen or camelCase member name reaches the UI.
    @Test func notConnectedReasonsReadAsPlainSentences() {
        let features = Set(SuiteServices.slotFeatures.values).union(["updater", "unknown-feature"])
        var reasons = Self.slotted.map { (slug: SuiteServices.slotFeatures[$0] ?? $0, text: SuiteServices.notConnected($0)) }
        reasons += features.map { (slug: $0, text: SuiteIdentity.notConnected($0)) }
        for (slug, text) in reasons {
            let reason = text ?? ""
            #expect(!reason.contains(slug) && !reason.contains("-") && !reason.contains("("), "\(reason)")
            #expect(reason.first?.isUppercase == true && reason.hasSuffix(" isn't available yet."), "\(reason)")
            let camel = reason.split(separator: " ").contains { word in
                zip(word, word.dropFirst()).contains { $0.isLowercase && $1.isUppercase }
            }
            #expect(!camel, "\(reason)")
        }
        #expect(SuiteServices.notConnected("roundTrips") == "Editing in Photo and back isn't available yet.")
    }
}
