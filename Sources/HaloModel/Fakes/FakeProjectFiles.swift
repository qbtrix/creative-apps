// Fakes/FakeProjectFiles.swift: a small, predictable ProjectFiles (#209). It
// checks the envelope, version and size, but not the contents' rules (unique
// names, spans, sorted keys, cycles). Linux-safe; never used by `.live`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The file envelope both the fake and the live type write.
struct HaloFileEnvelope: Codable {
    var format: String
    var version: Int
    var project: HaloDocumentState?
}

public struct FakeProjectFiles: ProjectFiles {
    public static let maxBytes = 64 * 1024 * 1024
    public init() {}
    public func encode(_ state: HaloDocumentState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(HaloFileEnvelope(format: "halo", version: 1, project: state))
    }
    public func decode(_ data: Data) throws -> HaloDocumentState {
        guard data.count <= Self.maxBytes else { throw HaloFileError.tooLarge }
        guard let head = try? JSONDecoder().decode(Header.self, from: data), head.format == "halo" else {
            throw HaloFileError.notAHaloFile
        }
        guard head.version <= 1 else { throw HaloFileError.newerVersion(head.version) }
        do {
            guard let project = try JSONDecoder().decode(HaloFileEnvelope.self, from: data).project else {
                throw HaloFileError.damaged("it has no project")
            }
            return project
        } catch let error as HaloFileError { throw error } catch { throw HaloFileError.damaged("\(error)") }
    }
    struct Header: Codable { var format: String; var version: Int }
}
