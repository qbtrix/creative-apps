// Fakes/FakeProjectFiles.swift: a small, predictable ProjectFiles (#209). A
// thin wrapper over `HaloFileFormat`, the envelope the live type writes: it
// checks size, format, version and project, but on purpose not the
// contents' rules (unique names, spans, keys, cycles). Linux-safe; never
// used by `.live`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct FakeProjectFiles: ProjectFiles {
    /// The file size limit, the envelope's.
    public static let maxBytes = HaloFileFormat.maxBytes
    public init() {}
    public func encode(_ state: HaloDocumentState) throws -> Data { try HaloFileFormat.encode(state) }
    public func decode(_ data: Data) throws -> HaloDocumentState { try HaloFileFormat.unwrap(data) }
}
