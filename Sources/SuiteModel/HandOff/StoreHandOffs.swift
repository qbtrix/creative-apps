// StoreHandOffs.swift: the hand-off files in `handoffs/` (UC-5, UC-5b;
// blueprint 2.6, hand-off transport). A sender writes the request as
// `handoffs/<id>.aghandoff` and asks the transport to deliver it; the
// receiver decodes it, and settles it when it is done. A pending request
// older than its lifetime is expired by the reader, and a settled file is
// swept away. Foundation only for the folder listing and dates, Linux-safe,
// Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor StoreHandOffs: HandOffSending, HandOffReceiving {
    private let store: FileStore
    private let from: SuiteApp
    private let deliver: @Sendable (String, SuiteApp) async throws(SuiteError) -> SwitchReceipt

    /// `deliver` gets the full path of the written file and the app it goes to.
    public init(store: FileStore, from: SuiteApp,
                deliver: @escaping @Sendable (String, SuiteApp) async throws(SuiteError) -> SwitchReceipt) {
        self.store = store; self.from = from; self.deliver = deliver
    }

    /// Writes the request under its id, stamped with this sender, then delivers it.
    public func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt {
        guard HandOffCodec.isSafeID(handOff.id) else { throw .damaged(HandOffCodec.subject) }
        var sent = handOff
        sent.from = from
        let name = Self.name(for: sent.id)
        try store.writeData(name, try HandOffCodec.encode(sent))
        return try await deliver(store.folder + "/" + name, sent.to)
    }

    /// Decodes a received request. One past its lifetime is settled as expired
    /// and refused; any other comes back accepted, and the caller settles it.
    public func receive(_ data: Data, now: Date) async throws(SuiteError) -> HandOff {
        var received = try HandOffCodec.decode(data)
        if received.isExpired(now: now) {
            try await settle(id: received.id, as: .expired)
            throw .notAvailable("This request expired.")
        }
        received.state = .accepted
        return received
    }

    /// Records `state` in the request's file. A file already gone has nothing to record.
    public func settle(id: String, as state: HandOffState) async throws(SuiteError) {
        let name = Self.name(for: id)
        guard let data = try store.readData(name) else { return }
        var handOff = try HandOffCodec.decode(data)
        handOff.state = state
        try store.writeData(name, try HandOffCodec.encode(handOff))
    }

    /// Expires each pending request past its lifetime, deletes each settled
    /// one, and returns how many files it changed. A file that won't decode is left alone.
    public func sweep(now: Date) throws(SuiteError) -> Int {
        let folder = store.folder + "/handoffs"
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder)) ?? []
        var changed = 0
        for name in names where name.hasSuffix(".aghandoff") {
            let relative = "handoffs/" + name
            guard let data = try store.readData(relative), let handOff = try? HandOffCodec.decode(data) else { continue }
            if handOff.state == .pending {
                guard handOff.isExpired(now: now) else { continue }
                try store.writeData(relative, try HandOffCodec.encode(withState(.expired, handOff)))
            } else {
                guard (try? FileManager.default.removeItem(atPath: store.folder + "/" + relative)) != nil else {
                    throw .ioFailed(HandOffCodec.subject)
                }
            }
            changed += 1
        }
        return changed
    }

    private func withState(_ state: HandOffState, _ handOff: HandOff) -> HandOff {
        var copy = handOff
        copy.state = state
        return copy
    }

    /// The file a hand-off with this id lives in, relative to the store folder.
    static func name(for id: String) -> String { "handoffs/\(id).aghandoff" }
}
