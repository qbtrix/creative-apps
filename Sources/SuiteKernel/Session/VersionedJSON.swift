// VersionedJSON.swift (EK-3 stub, EK-24 body): a JSON format version and decoding-error words.
// `probe` reads the integer version at the top of a JSON object before the document is
// decoded, and refuses a file newer than the app reads; `words` names the coding path.
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
    /// The integer version stored under `key` at the top of `data`. Throws
    /// `damaged` when `data` is not a JSON object and `missing(key)` when the
    /// key is absent or its value is not an integer.
    public static func probe(_ data: Data, key: String = "version") throws(VersionError) -> Int {
        let top: [String: ProbedValue]
        do {
            top = try JSONDecoder().decode([String: ProbedValue].self, from: data)
        } catch {
            throw VersionError.damaged
        }
        guard let version = top[key]?.integer else { throw VersionError.missing(key) }
        return version
    }

    /// The version under `key`, refused as `newer` when it is above `supported`,
    /// so the alert can name both versions.
    public static func probe(_ data: Data, key: String = "version", supported: Int) throws(VersionError) -> Int {
        let version = try probe(data, key: key)
        guard version <= supported else { throw VersionError.newer(found: version, supported: supported) }
        return version
    }

    /// A decoding error in words, naming the coding path where reading stopped.
    public static func words(for error: DecodingError) -> String {
        switch error {
        case let .keyNotFound(key, context):
            return "The file is missing \(place(context.codingPath + [key]))."
        case let .valueNotFound(_, context):
            return "The file has no value at \(place(context.codingPath))."
        case let .typeMismatch(_, context):
            return "The file has the wrong kind of value at \(place(context.codingPath))."
        case let .dataCorrupted(context):
            return "The file is damaged at \(place(context.codingPath))."
        @unknown default:
            return "The file could not be read."
        }
    }

    /// A coding path as `layers[1].opacity`, or the top of the file when empty.
    static func place(_ path: [any CodingKey]) -> String {
        let names = path.map { key in key.intValue.map { "[\($0)]" } ?? key.stringValue }
        guard !names.isEmpty else { return "the top of the file" }
        return "\u{201C}" + names.reduce("") { $0.isEmpty || $1.hasPrefix("[") ? $0 + $1 : $0 + "." + $1 } + "\u{201D}"
    }
}

/// One top-level value, kept only when it is an integer; anything else decodes as nil.
private struct ProbedValue: Decodable {
    let integer: Int?

    init(from decoder: any Decoder) throws {
        integer = try? decoder.singleValueContainer().decode(Int.self)
    }
}
