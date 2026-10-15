// Live/LiveProjectFiles.swift: the live ProjectFiles (#209). Encodes and
// unwraps through `HaloFileFormat`, the one copy of the envelope. Content
// validation (unique ids and names, spans, keys, parents, counters) joins
// `decode` in HF-5. Linux-safe.
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
        // HF-5 seam: check the contents and raise the counters here.
        return state
    }
}
