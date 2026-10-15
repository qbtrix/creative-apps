// Live/HaloFileEnvelope.swift: the one copy of the .halo envelope (#209),
// shared by LiveProjectFiles and FakeProjectFiles. A file is JSON with
// sorted keys: {"format":"halo","project":{...},"version":1}. Unwrapping
// checks size before parsing, then format, version and project; the
// project's contents are checked by the live type alone (HF-5). Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What a .halo file holds around the project.
struct HaloFileEnvelope: Codable {
    var format: String
    var version: Int
    var project: HaloDocumentState?
}

/// Writes and unwraps the envelope.
enum HaloFileFormat {
    /// The largest file Halo opens: 64 MiB.
    static let maxBytes = 64 * 1024 * 1024
    static let format = "halo"
    static let version = 1

    /// The project in its envelope, keys sorted so a save is byte-stable.
    static func encode(_ state: HaloDocumentState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(HaloFileEnvelope(format: format, version: version, project: state))
    }

    /// The project inside `data`. Throws `.tooLarge` before parsing,
    /// `.notAHaloFile`, `.newerVersion(v)`, or `.damaged(reason)`.
    static func unwrap(_ data: Data) throws -> HaloDocumentState {
        guard data.count <= maxBytes else { throw HaloFileError.tooLarge }
        let decoder = JSONDecoder()
        guard let head = try? decoder.decode(Header.self, from: data), head.format == format else {
            throw HaloFileError.notAHaloFile
        }
        guard head.version <= version else { throw HaloFileError.newerVersion(head.version) }
        let envelope: HaloFileEnvelope
        do {
            envelope = try decoder.decode(HaloFileEnvelope.self, from: data)
        } catch let error as DecodingError {
            throw HaloFileError.damaged(reason(error))
        } catch {
            throw HaloFileError.damaged("it can't be read")
        }
        guard let project = envelope.project else { throw HaloFileError.damaged("it has no project") }
        return project
    }

    /// A short reason for a decoding failure, naming where in the project
    /// it happened: "it is missing name in compositions[0]".
    static func reason(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            "it is missing \(key.stringValue)\(place(context.codingPath))"
        case .valueNotFound(_, let context):
            "it has no value at \(path(context.codingPath))"
        case .typeMismatch(_, let context):
            "it has the wrong kind of value at \(path(context.codingPath))"
        case .dataCorrupted(let context):
            context.codingPath.isEmpty ? "it isn't valid JSON" : "it has a bad value at \(path(context.codingPath))"
        @unknown default:
            "it can't be read"
        }
    }

    /// " in compositions[0]", or "" at the top of the project.
    private static func place(_ codingPath: [any CodingKey]) -> String {
        let spot = path(codingPath)
        return spot == "the project" ? "" : " in \(spot)"
    }

    /// "compositions[0].layers[2]", dropping the envelope's "project" key.
    private static func path(_ codingPath: [any CodingKey]) -> String {
        var text = ""
        for (offset, key) in codingPath.enumerated() {
            if offset == 0 && key.stringValue == "project" { continue }
            if let index = key.intValue, key.stringValue == "Index \(index)" {
                text += "[\(index)]"
            } else {
                text += text.isEmpty ? key.stringValue : ".\(key.stringValue)"
            }
        }
        return text.isEmpty ? "the project" : text
    }

    /// Just enough to tell a Halo file and its version.
    private struct Header: Decodable {
        var format: String
        var version: Int
    }
}
