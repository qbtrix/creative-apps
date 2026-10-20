// ExportOptions.swift (export-pack XP-1 values and stubs, XP-6 bodies): the suite's one export options model,
// the rules that turn a size into exact pixels and a metadata policy into the tags to drop, and the format list.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// How big an export is: a scale of the scope's own size, exact pixels, or the long side's length.
public enum SuiteExportSize: Hashable, Codable, Sendable {
    /// 1x, 2x, 0.5x of the scope's own size.
    case scale(Double)
    /// Exactly `width` × `height`; without `stretch` the shape must match the artwork's.
    case pixels(width: Int, height: Int, stretch: Bool = false)
    /// The long side this many pixels, the short side in proportion.
    case longEdge(Int)
}

/// Which metadata an export carries: everything, everything but where it was made, or nothing.
public enum ExportMetadata: String, Hashable, Codable, CaseIterable, Sendable {
    case all, noLocation, none
    /// The picker's title: "All", "All but location", "None".
    public var title: String {
        switch self {
        case .all: "All"
        case .noLocation: "All but location"
        case .none: "None"
        }
    }
}

/// One format the suite writes and what it can carry.
public struct ExportFormatSpec: Hashable, Sendable {
    public enum Kind: String, Sendable { case still, vector, movie, animated }
    public let id: String, name: String, fileExtension: String, kind: Kind
    public let hasQuality: Bool, keepsAlpha: Bool, carriesMetadata: Bool, needsEvenSize: Bool

    public init(id: String, name: String, fileExtension: String, kind: Kind,
                hasQuality: Bool, keepsAlpha: Bool, carriesMetadata: Bool, needsEvenSize: Bool) {
        (self.id, self.name, self.fileExtension, self.kind) = (id, name, fileExtension, kind)
        (self.hasQuality, self.keepsAlpha, self.carriesMetadata, self.needsEvenSize) = (hasQuality, keepsAlpha, carriesMetadata, needsEvenSize)
    }
}

/// The suite's format list.
public enum ExportFormats {
    /// png, jpeg, heic, tiff, svg, pdf, mp4 (H.264), mp4-hevc, mov-prores (ProRes 4444, alpha), gif, apng.
    public static let all: [ExportFormatSpec] = []

    /// The format with this id, nil when the suite has none.
    public static func spec(_ id: String) -> ExportFormatSpec? { all.first { $0.id == id } }
}

/// Why export options can't run, in words the sheet and the CLI show.
public enum ExportOptionRefusal: Error, Hashable, Sendable, CustomStringConvertible {
    case invalid(String), notBuilt
    public var description: String { if case .invalid(let why) = self { why } else { "Export options are not built yet (export-pack)." } }
}

/// One export's options: what every app's sheet, the CLI and MCP ask for.
public struct SuiteExportOptions: Hashable, Codable, Sendable {
    /// A format id from `ExportFormats`, the size, and quality 0...1 for formats that have one.
    public var format: String, size: SuiteExportSize, quality: Double
    /// The metadata policy, whether transparency is kept, and a movie's frame rate and looping.
    public var metadata: ExportMetadata, alpha: Bool, fps: Int?, loop: Bool

    public init(format: String = "png", size: SuiteExportSize = .scale(1), quality: Double = 0.9,
                metadata: ExportMetadata = .all, alpha: Bool = false, fps: Int? = nil, loop: Bool = false) {
        (self.format, self.size, self.quality) = (format, size, quality)
        (self.metadata, self.alpha, self.fps, self.loop) = (metadata, alpha, fps, loop)
    }

    /// The one params schema: every key optional, each missing one from `defaults`; an unknown key throws.
    public init(json: JSONValue, defaults: SuiteExportOptions) throws { self = defaults }

    /// `{"format", "size": {"scale" | "pixels": [w, h] | "longEdge", "stretch"}, "quality", "metadata", "alpha", "fps", "loop"}`.
    public static let schema = ParamSchema.object([
        "format": .optional(.string("A format id, such as png, jpeg or mp4.")),
        "size": .optional(.object([
            "scale": .optional(.number("A scale of the artwork's own size.")),
            "pixels": .optional(.array(of: .integer(minimum: 1), minItems: 2, maxItems: 2)),
            "longEdge": .optional(.integer("The long side in pixels.", minimum: 1)),
            "stretch": .optional(.boolean),
        ], required: [], description: "One of scale, pixels or longEdge; stretch lets pixels change the shape.")),
        "quality": .optional(.number("0 to 1, for formats that have a quality.", minimum: 0, maximum: 1)),
        "metadata": .optional(.string("Which metadata to keep.", oneOf: ExportMetadata.allCases.map(\.rawValue))),
        "alpha": .optional(.boolean),
        "fps": .optional(.integer("Frames per second, for movies and animations.", minimum: 1, maximum: 240)),
        "loop": .optional(.boolean),
    ], required: [], description: "Export options; a missing key keeps its default.")
}

/// The rules every export follows.
public enum ExportRules {
    /// The longest side any export writes, in pixels.
    public static let maxSide = 16_384

    /// Exact output pixels for a scope `source` pixels big at 1x.
    public static func pixels(of source: (width: Int, height: Int), _ size: SuiteExportSize,
                              evenSize: Bool) throws -> (width: Int, height: Int) { source }

    /// ImageIO property paths to drop ("{GPS}", "{Exif}.BodySerialNumber", "{MakerApple}", ...) and the XMP
    /// properties a sidecar leaves out ("exif:GPSLatitude", "xmp:CreateDate" under `.none`).
    public static func dropped(_ m: ExportMetadata) -> (properties: Set<String>, xmp: Set<String>) { ([], []) }

    /// Why these options can't run, or nil.
    public static func refusal(_ o: SuiteExportOptions, source: (width: Int, height: Int), formats: [ExportFormatSpec]) -> String? { nil }
}
