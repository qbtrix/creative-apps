// FakeMetadata.swift: the in-memory MetadataCarrying (export-pack XP-2).
// Records each `carrying` call in order and returns the still unchanged;
// `properties(of:)` answers the set it was made with. With `unavailable:` set,
// every call throws `.notAvailable(that sentence)` and records nothing.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

public final class FakeMetadata: MetadataCarrying {
    /// One `carrying` call: the still, its source and the paths it dropped.
    public struct Carry: Hashable, Sendable {
        public let still: Data, source: Data, dropping: Set<String>
    }

    private let log = Mutex([Carry]())
    let unavailable: String?
    let present: Set<String>

    public init(properties: Set<String> = [], unavailable: String? = nil) {
        self.present = properties; self.unavailable = unavailable
    }

    /// Every `carrying` call, in order.
    public var carried: [Carry] { log.withLock { $0 } }

    public func carrying(_ still: Data, from source: Data, dropping: Set<String>) throws(SuiteError) -> Data {
        if let unavailable { throw .notAvailable(unavailable) }
        log.withLock { $0.append(Carry(still: still, source: source, dropping: dropping)) }
        return still
    }

    public func properties(of image: Data) throws(SuiteError) -> Set<String> {
        if let unavailable { throw .notAvailable(unavailable) }
        return present
    }
}
