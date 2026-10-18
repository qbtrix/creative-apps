// VersionedJSON.swift (EK-3 stub, EK-24 body): a JSON format version and decoding-error words.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Why `VersionedJSON.probe` could not read a version: not a JSON object
/// (`damaged`), no version under the key, or newer than this app reads.
public enum VersionError: Error, Equatable, Sendable { case damaged, missing(String), newer(found: Int, supported: Int) }

/// Version probing and decoding-error words for JSON documents.
public enum VersionedJSON {
    /// The integer version stored under `key` at the top of `data`. Stub: 1 until EK-24.
    public static func probe(_ data: Data, key: String = "version") throws(VersionError) -> Int { 1 }

    /// A decoding error in words, naming the coding path. Stub: a fixed sentence until EK-24.
    public static func words(for error: DecodingError) -> String { "The file could not be read." }
}
