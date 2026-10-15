// Live/LiveProjectFiles.swift: the live ProjectFiles (#209). Encodes and
// unwraps through `HaloFileFormat`, the one copy of the envelope, then
// checks the contents and raises the id counters (`HaloFileValidation`).
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LiveProjectFiles: ProjectFiles {
    public init() {}
    public func encode(_ state: HaloDocumentState) throws -> Data { try HaloFileFormat.encode(state) }
    public func decode(_ data: Data) throws -> HaloDocumentState {
        let state = try HaloFileFormat.unwrap(data)
        try HaloFileValidation.check(state)
        return HaloFileValidation.raisingCounters(state)
    }
}
