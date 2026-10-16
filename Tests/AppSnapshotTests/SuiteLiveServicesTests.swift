// SuiteLiveServicesTests.swift: SuiteServices.live over a temp support
// folder (suite-contracts SC-5b). It is not a preview; recents is live and
// writes recents.json there; every other slotted member is pending with its
// "Not connected yet (<feature>)." sentence, and each throwing one throws
// notAvailable with that sentence. macOS only (SuiteShell).
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

    @Test func everyOtherSlottedMemberIsPendingWithItsFeature() {
        let pending = makeLive().services.pending
        var expected = SuiteServices.slotFeatures.mapValues(SuiteIdentity.notConnected)
        expected["recents"] = nil
        #expect(pending == expected)
        #expect(pending.count == 14)
        #expect(pending["sending"] == "Not connected yet (switching).")
        #expect(pending["thumbnails"] == "Not connected yet (recents-open-in).")
        #expect(pending["home"] == "Not connected yet (home).")
        #expect(pending["onboarding"] == "Not connected yet (onboarding).")
    }

    @Test func throwingMembersNotLiveThrowTheirReason() async throws {
        let s = makeLive().services
        let preset = NewDocumentPreset(id: "design.blank", app: .design, title: "Blank", detail: "One page")
        let handOff = s.creating.handOff(for: preset, id: "h1", at: now)
        let logo = ref("Logo.design")
        await #expect(throws: reason("switching")) { _ = try await s.switching.switchTo(.design, reason: .menu) }
        await #expect(throws: reason("sending")) { _ = try await s.sending.send(handOff) }
        await #expect(throws: reason("receiving")) { _ = try await s.receiving.receive(Data(), now: now) }
        await #expect(throws: reason("receiving")) { try await s.receiving.settle(id: "h1", as: .accepted) }
        await #expect(throws: reason("thumbnails")) { _ = try await s.thumbnails.publish(png: Data(), for: logo) }
        await #expect(throws: reason("roundTrips")) { try await s.roundTrips.cancel(session: "r1") }
        await #expect(throws: reason("assets")) { _ = try await s.assets.index() }
        await #expect(throws: reason("preferences")) { _ = try await s.preferences.load() }
        await #expect(throws: reason("settings")) { try await s.settings.open(.general, from: .launcher) }
    }

    @Test func pureMembersAreTheReferenceFakes() throws {
        let s = makeLive().services
        #expect(try s.routing.route(fileName: "Logo.design") == .design)
        #expect(s.creating.tiles(missing: []).allSatisfy { $0.disabledReason == nil })
        #expect(s.onboarding.pages.count == 3)
    }
}
