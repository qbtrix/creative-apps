// Live/LiveProjectFiles.swift: the W0 stub of ProjectFiles. Encoding and
// decoding throw `.notBuilt`; the files feature (#209) replaces this file
// whole with the live type. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LiveProjectFiles: ProjectFiles {
    public init() {}
    public var unavailableHelp: String? { "Saving and opening projects arrive with #209." }
    public func encode(_ state: HaloDocumentState) throws -> Data { throw HaloEditError.notBuilt("Saving") }
    public func decode(_ data: Data) throws -> HaloDocumentState { throw HaloEditError.notBuilt("Opening") }
}
