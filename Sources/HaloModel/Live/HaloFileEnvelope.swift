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

    /// A short reason for a decoding failure, naming where in the project it
    /// happened in words: "the first composition is missing its name".
    static func reason(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            "\(place(context.codingPath) ?? "it") is missing its \(words(key.stringValue))"
        case .valueNotFound(_, let context):
            "\(place(context.codingPath) ?? "it") has no value"
        case .typeMismatch(_, let context):
            "\(place(context.codingPath) ?? "it") has a value of the wrong kind"
        case .dataCorrupted(let context):
            context.codingPath.isEmpty
                ? "its contents can't be read" : "\(place(context.codingPath) ?? "it") has a value of the wrong kind"
        @unknown default:
            "it can't be read"
        }
    }

    /// The coding path in words, or nil at the top of the project:
    /// compositions[0].layers[2] is "the first composition's third layer",
    /// a layer's tracks.x[1] its "second x keyframe". The envelope's
    /// "project" key is dropped.
    private static func place(_ codingPath: [any CodingKey]) -> String? {
        var keys = codingPath.map(\.stringValue)
        var indexes = codingPath.map(\.intValue)
        if keys.first == "project", indexes.first == .some(nil) {
            keys.removeFirst()
            indexes.removeFirst()
        }
        var parts: [String] = []
        var at = 0
        while at < keys.count {
            let next = at + 1 < keys.count ? indexes[at + 1] : nil
            if let index = indexes[at] {
                parts.append("\(ordinal(index + 1)) item")
            } else if let index = next {
                let underTracks = at > 0 && keys[at - 1] == "tracks"
                let thing = underTracks ? "\(words(keys[at])) keyframe" : singular(words(keys[at]))
                parts.append("\(ordinal(index + 1)) \(thing)")
                at += 1
            } else if keys[at] != "tracks" || at + 1 == keys.count {
                parts.append(words(keys[at]))
            }
            at += 1
        }
        return parts.isEmpty ? nil : "the " + parts.joined(separator: "'s ")
    }

    /// A coding key in words: "framesPerSecond" is "frames per second",
    /// "parentID" is "parent id".
    static func words(_ key: String) -> String {
        var text = ""
        var previous: Character?
        for character in key {
            if character.isUppercase, let previous, previous.isLowercase { text.append(" ") }
            text.append(character)
            previous = character
        }
        return text.lowercased()
    }

    /// "compositions" is "composition".
    private static func singular(_ word: String) -> String {
        word.hasSuffix("s") ? String(word.dropLast()) : word
    }

    /// 1 is "first", 12 is "12th", 23 is "23rd".
    static func ordinal(_ number: Int) -> String {
        let named = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]
        if number >= 1, number <= named.count { return named[number - 1] }
        let teen = (number % 100) / 10 == 1
        let suffix = teen ? "th" : [1: "st", 2: "nd", 3: "rd"][number % 10] ?? "th"
        return "\(number)\(suffix)"
    }

    /// Just enough to tell a Halo file and its version.
    private struct Header: Decodable {
        var format: String
        var version: Int
    }
}
