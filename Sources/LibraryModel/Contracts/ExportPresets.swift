// Contracts/ExportPresets.swift (EX-1 slot, filled by EX-10): saved export settings, Library-local (#3091).
// A new preset's unique name comes from SuiteModel's UniqueFileNames (contract rule 20).
import SuiteModel
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Every export option but the folder, under a name.
public struct ExportPreset: Hashable, Sendable, Codable, Identifiable {
    public var id: String, name: String
    public var longEdge: Int?, quality: Int, format: ExportFormat, naming: ExportNaming, sidecar: Bool
    public var isBuiltIn = false

    public init(name: String, options: ExportOptions) {
        (id, self.name, longEdge, quality) = (name, name, options.longEdge, options.quality)
        (format, naming, sidecar) = (options.format, options.naming, options.sidecar)
    }

    /// `options` with every field of this preset but the folder.
    public func applied(to options: ExportOptions) -> ExportOptions {
        ExportOptions(longEdge: longEdge, quality: quality, folder: options.folder,
                      format: format, naming: naming, sidecar: sidecar)
    }
}

/// What the export area stores: the presets and the last options used.
public struct ExportPresetFile: Hashable, Sendable, Codable {
    public var presets: [ExportPreset], last: ExportOptions?
    public init(presets: [ExportPreset] = [], last: ExportOptions? = nil) { (self.presets, self.last) = (presets, last) }
}

/// The preset list's rules: three JPEG built-ins first, unique names, built-ins never removed.
public enum ExportPresets {
    public static let unavailable: String? = nil

    /// "For Sharing" 2048/85, "Full Size" original/95, "Small" 1024/80; all JPEG.
    public static var builtIns: [ExportPreset] {
        let specs: [(String, Int?, Int)] = [("For Sharing", 2048, 85), ("Full Size", nil, 95), ("Small", 1024, 80)]
        return specs.map { name, edge, quality in
            var preset = ExportPreset(name: name, options: ExportOptions(longEdge: edge, quality: quality, folder: ""))
            preset.isBuiltIn = true
            return preset
        }
    }

    /// `list` plus `preset` as a user preset, named "Name 2", "Name 3", … when its name is taken.
    public static func adding(_ preset: ExportPreset, to list: [ExportPreset]) -> [ExportPreset] {
        let taken = Set(list.map(\.name))
        var added = preset
        added.name = UniqueFileNames.name(preset.name, extension: "", among: taken)
        added.id = added.name
        added.isBuiltIn = false
        return list + [added]
    }

    /// `list` without the user preset `id`; a built-in stays.
    public static func removing(_ id: String, from list: [ExportPreset]) -> [ExportPreset] {
        list.filter { $0.id != id || $0.isBuiltIn }
    }

    /// The stored file: the built-ins, then its user presets, and its last options.
    /// Missing or damaged data gives the built-ins and no last options; it never throws.
    public static func decode(_ data: Data?) -> ExportPresetFile {
        guard let data, let file = try? JSONDecoder().decode(ExportPresetFile.self, from: data) else {
            return ExportPresetFile(presets: builtIns)
        }
        return ExportPresetFile(presets: builtIns + file.presets.filter { !$0.isBuiltIn }, last: file.last)
    }

    public static func encode(_ file: ExportPresetFile) -> Data { (try? JSONEncoder().encode(file)) ?? Data() }
}
