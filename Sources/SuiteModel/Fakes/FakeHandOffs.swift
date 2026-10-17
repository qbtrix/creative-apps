// FakeHandOffs.swift: the in-memory HandOffSending and HandOffReceiving
// (UC-5, UC-5b). Sending switches to the target through a FakeSwitching; an
// expired hand-off is refused. With `unavailable:` set, every throwing call
// throws `.notAvailable(that sentence)`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor FakeHandOffs: HandOffSending, HandOffReceiving {
    public private(set) var sent: [HandOff] = []
    public private(set) var settled: [String: HandOffState] = [:]
    let unavailable: String?
    let switching: FakeSwitching
    public init(switching: FakeSwitching = FakeSwitching(), unavailable: String? = nil) {
        self.switching = switching; self.unavailable = unavailable
    }
    public func send(_ handOff: HandOff) async throws(SuiteError) -> SwitchReceipt {
        if let unavailable { throw .notAvailable(unavailable) }
        sent.append(handOff)
        return try await switching.switchTo(handOff.to, reason: .handOff)
    }
    public func receive(_ data: Data, now: Date) throws(SuiteError) -> HandOff {
        if let unavailable { throw .notAvailable(unavailable) }
        var h = try HandOffCodec.decode(data)
        if h.isExpired(now: now) { settled[h.id] = .expired; throw .notAvailable("This request expired.") }
        h.state = .accepted
        settled[h.id] = .accepted
        return h
    }
    public func settle(id: String, as state: HandOffState) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        settled[id] = state
    }
}
