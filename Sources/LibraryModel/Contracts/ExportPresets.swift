// Contracts/ExportPresets.swift (EX-1 slot, filled by EX-10): saved export settings and
// the file the export area stores. Library-local: no shared module holds presets yet.
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

/// The preset list's rules; every one is a slot until EX-10.
public enum ExportPresets {
    public static let unavailable: String? = "Presets aren't built yet (export presets)."
    public static var builtIns: [ExportPreset] { [] }
    public static func adding(_ preset: ExportPreset, to list: [ExportPreset]) -> [ExportPreset] { list }
    public static func removing(_ id: String, from list: [ExportPreset]) -> [ExportPreset] { list }
    public static func decode(_ data: Data?) -> ExportPresetFile { ExportPresetFile() }
    public static func encode(_ file: ExportPresetFile) -> Data { (try? JSONEncoder().encode(file)) ?? Data() }
}
