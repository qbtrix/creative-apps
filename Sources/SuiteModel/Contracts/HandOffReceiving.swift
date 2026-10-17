// HandOffReceiving.swift: UC-5b, receive and settle hand-offs (every app).
// Foundation only for `Data` and `Date`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-5b Receive and settle hand-offs (every app). Live: `FileStore` over `handoffs/`.
public protocol HandOffReceiving: Sendable {
    func receive(_ data: Data, now: Date) async throws(SuiteError) -> HandOff
    func settle(id: String, as state: HandOffState) async throws(SuiteError)
}
