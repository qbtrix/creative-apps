// ValuesHandOffTests.swift: the `.aghandoff` format round-trips byte for
// byte, refuses a newer format by name and an id that could name a nested
// path; ids are lowercase UUIDs; a pending hand-off expires after 7 days.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct ValuesHandOffTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func sample(id: String = "0f8e2a3c-1b2d-4e5f-8a9b-0c1d2e3f4a5b") -> HandOff {
        let path = "/tmp/Documents/Bounce.flare"
        let doc = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .flare,
                                   type: .flareAnimation, displayName: "Bounce.flare")
        let preset = NewDocumentPreset(id: "flare.vertical", app: .flare, title: "Vertical 9:16",
                                       detail: "1080 × 1920, 30 fps", parameters: ["width": "1080", "height": "1920"])
        return HandOff(id: id, from: .launcher, to: .flare, verb: .new, documents: [doc], preset: preset,
                       asset: AssetLink(assetID: "a1", kind: .vector, placedRevision: 2),
                       settingsPane: .app(.flare), session: "s1", returnTo: .halo, createdAt: now)
    }

    @Test func encodeDecodeEncodeIsByteEqual() throws {
        let h = sample()
        let data = try HandOffCodec.encode(h)
        let back = try HandOffCodec.decode(data)
        #expect(back == h)
        #expect(back.format == HandOff.formatVersion)
        #expect(try HandOffCodec.encode(back) == data)
    }

    @Test func aNewerFormatIsRefusedByName() {
        let newer = Data("{\"format\":2}".utf8)
        #expect(throws: SuiteError.notAvailable("This was sent by a newer AfterGlow. Update AfterGlow to open it.")) {
            try HandOffCodec.decode(newer)
        }
    }

    @Test func notAHandOffIsDamaged() {
        let plain = SuiteError.damaged("the message from another app")
        #expect(throws: plain) { try HandOffCodec.decode(Data("[]".utf8)) }
        #expect(throws: plain) { try HandOffCodec.decode(Data("{\"format\":1}".utf8)) }
    }

    @Test(arguments: ["../outside", "a/b", "", "ABC-def", "id with space", "x.y"])
    func anUnsafeIDIsDamaged(id: String) throws {
        let data = try HandOffCodec.encode(sample(id: id))
        do {
            _ = try HandOffCodec.decode(data)
            Issue.record("an unsafe id decoded")
        } catch {
            #expect(error == .damaged("the message from another app"))
            #expect(!error.message.contains("hand-off"))
        }
    }

    @Test func newIDIsALowercaseUUIDAndUnique() throws {
        let a = HandOff.newID()
        let b = HandOff.newID()
        #expect(a.count == 36)
        #expect(a == a.lowercased())
        #expect(a != b)
        #expect(UUID(uuidString: a) != nil)
        #expect(try HandOffCodec.decode(HandOffCodec.encode(sample(id: a))).id == a)
    }

    @Test func expiresOnlyWhenPendingPastSevenDays() {
        let week: Double = 7 * 24 * 3600
        #expect(HandOff.lifetime == week)
        let h = sample()
        #expect(!h.isExpired(now: now + week))
        #expect(h.isExpired(now: now + week + 1))
        var accepted = h
        accepted.state = .accepted
        #expect(!accepted.isExpired(now: now + week + 1))
    }

    @Test func switchingValues() {
        let receipt = SwitchReceipt(app: .design, wasRunning: true, requestedAt: 12.5)
        #expect(receipt == SwitchReceipt(app: .design, wasRunning: true, requestedAt: 12.5))
        #expect(AppRunState.running(windows: 2) != .running(windows: 1))
        #expect(SwitchReason(rawValue: "handOff") == .handOff)
    }
}
