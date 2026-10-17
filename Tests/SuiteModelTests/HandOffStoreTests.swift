// HandOffStoreTests.swift: the hand-off files a sender writes and a receiver
// settles (SW-2; blueprint 2.6): the path a send writes, expiry on receive,
// settling, sweeping, and refusing a newer format.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

/// Records the path each delivery was asked for, from concurrent sends.
actor DeliveryLog {
    private(set) var paths: [String] = []
    func record(_ path: String) { paths.append(path) }
}

@Suite struct HandOffStoreTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeStore() -> FileStore {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("HandOffStoreTests-\(UUID().uuidString)").path
        return FileStore(folder: folder)
    }

    private func makeHandOff(id: String = "a1b2c3d4-0000-4000-8000-000000000001", createdAt: Date? = nil,
                             state: HandOffState = .pending) -> HandOff {
        HandOff(id: id, from: .launcher, to: .design, verb: .open, createdAt: createdAt ?? now, state: state)
    }

    private func onDisk(_ store: FileStore, _ handOff: HandOff) throws -> HandOff? {
        guard let data = try store.readData("handoffs/\(handOff.id).aghandoff") else { return nil }
        return try HandOffCodec.decode(data)
    }

    @Test func sendWritesTheFileUnderItsIdAndDeliversThatPath() async throws {
        let store = makeStore()
        let log = DeliveryLog()
        let sender = StoreHandOffs(store: store, from: .launcher) { path, app async throws(SuiteError) -> SwitchReceipt in
            await log.record(path)
            return SwitchReceipt(app: app, wasRunning: true, requestedAt: 0)
        }
        let handOff = makeHandOff()
        let receipt = try await sender.send(handOff)
        #expect(receipt.app == .design)
        #expect(await log.paths == [store.folder + "/handoffs/\(handOff.id).aghandoff"])
        #expect(try store.readData("handoffs/\(handOff.id).aghandoff") != nil)
    }

    @Test func aStaleIdIsRefusedAndNothingIsWritten() async {
        let store = makeStore()
        let sender = StoreHandOffs(store: store, from: .launcher) { _, app async throws(SuiteError) -> SwitchReceipt in
            SwitchReceipt(app: app, wasRunning: true, requestedAt: 0)
        }
        await #expect(throws: SuiteError.damaged("the message from another app")) {
            try await sender.send(makeHandOff(id: "../escape"))
        }
    }

    @Test func aSevenDayOldPendingRequestSettlesExpiredOnReceive() async throws {
        let store = makeStore()
        let receiver = StoreHandOffs(store: store, from: .design) { _, app async throws(SuiteError) -> SwitchReceipt in
            SwitchReceipt(app: app, wasRunning: true, requestedAt: 0)
        }
        let old = makeHandOff(createdAt: now - HandOff.lifetime - 1)
        let data = try HandOffCodec.encode(old)
        try store.writeData("handoffs/\(old.id).aghandoff", data)
        await #expect(throws: SuiteError.notAvailable("This request expired.")) {
            try await receiver.receive(data, now: now)
        }
        #expect(try onDisk(store, old)?.state == .expired)
    }

    @Test func aFreshRequestIsAcceptedAndNotYetSettled() async throws {
        let store = makeStore()
        let receiver = StoreHandOffs(store: store, from: .design) { _, app async throws(SuiteError) -> SwitchReceipt in
            SwitchReceipt(app: app, wasRunning: true, requestedAt: 0)
        }
        let fresh = makeHandOff()
        let received = try await receiver.receive(try HandOffCodec.encode(fresh), now: now)
        #expect(received.state == .accepted)
    }

    @Test func settledThenSweptFileIsDeleted() async throws {
        let store = makeStore()
        let handOffs = StoreHandOffs(store: store, from: .launcher) { _, app async throws(SuiteError) -> SwitchReceipt in
            SwitchReceipt(app: app, wasRunning: true, requestedAt: 0)
        }
        let handOff = makeHandOff()
        try store.writeData("handoffs/\(handOff.id).aghandoff", try HandOffCodec.encode(handOff))
        try await handOffs.settle(id: handOff.id, as: .returned)
        #expect(try onDisk(store, handOff)?.state == .returned)
        #expect(try await handOffs.sweep(now: now) == 1)
        #expect(try store.readData("handoffs/\(handOff.id).aghandoff") == nil)
    }

    @Test func sweepExpiresAPendingRequestPastItsLifetime() async throws {
        let store = makeStore()
        let handOffs = StoreHandOffs(store: store, from: .launcher) { _, app async throws(SuiteError) -> SwitchReceipt in
            SwitchReceipt(app: app, wasRunning: true, requestedAt: 0)
        }
        let old = makeHandOff(createdAt: now - HandOff.lifetime - 1)
        try store.writeData("handoffs/\(old.id).aghandoff", try HandOffCodec.encode(old))
        #expect(try await handOffs.sweep(now: now) == 1)
        #expect(try onDisk(store, old)?.state == .expired)
    }

    @Test func aNewerFormatIsRefusedByName() throws {
        var newer = makeHandOff()
        newer.format = 2
        let data = try HandOffCodec.encode(newer)
        #expect(throws: SuiteError.notAvailable("This was sent by a newer AfterGlow. Update AfterGlow to open it.")) {
            try HandOffCodec.decode(data)
        }
    }
}
