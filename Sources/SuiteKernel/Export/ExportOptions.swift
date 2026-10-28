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
    public static let all: [ExportFormatSpec] = [
        entry("png", "PNG", "png", .still, alpha: true, metadata: true),
        entry("jpeg", "JPEG", "jpg", .still, quality: true, metadata: true),
        entry("heic", "HEIC", "heic", .still, quality: true, alpha: true, metadata: true),
        entry("tiff", "TIFF", "tiff", .still, alpha: true, metadata: true),
        entry("svg", "SVG", "svg", .vector, alpha: true),
        entry("pdf", "PDF", "pdf", .vector, alpha: true),
        entry("mp4", "H.264", "mp4", .movie, quality: true, even: true),
        entry("mp4-hevc", "HEVC", "mp4", .movie, quality: true, even: true),
        entry("mov-prores", "ProRes 4444", "mov", .movie, alpha: true, even: true),
        entry("gif", "GIF", "gif", .animated, alpha: true),
        entry("apng", "Animated PNG", "png", .animated, alpha: true),
    ]

    /// The format with this id, nil when the suite has none.
    public static func spec(_ id: String) -> ExportFormatSpec? { all.first { $0.id == id } }

    /// One row of the list; every flag off unless named.
    private static func entry(_ id: String, _ name: String, _ fileExtension: String, _ kind: ExportFormatSpec.Kind,
                              quality: Bool = false, alpha: Bool = false, metadata: Bool = false, even: Bool = false) -> ExportFormatSpec {
        ExportFormatSpec(id: id, name: name, fileExtension: fileExtension, kind: kind,
                         hasQuality: quality, keepsAlpha: alpha, carriesMetadata: metadata, needsEvenSize: even)
    }
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
    /// `.null` is `defaults`; a schema issue throws in words, never its JSON pointer (`plain(_:)`).
    public init(json: JSONValue, defaults: SuiteExportOptions) throws {
        self = defaults
        if case .null = json { return }
        if let issue = Self.schema.validate(json).first { throw ExportOptionRefusal.invalid(Self.plain(issue)) }
        guard case .object(let o) = json else { return }
        if case .string(let f)? = o["format"] { format = f }
        if case .object(let s)? = o["size"] { size = try Self.size(s) }
        if case .number(let q)? = o["quality"] { quality = q }
        if case .string(let m)? = o["metadata"], let policy = ExportMetadata(rawValue: m) { metadata = policy }
        if case .bool(let a)? = o["alpha"] { alpha = a }
        if case .number(let r)? = o["fps"] { fps = Int(exactly: r) }
        if case .bool(let l)? = o["loop"] { loop = l }
    }

    /// A schema issue as a sentence: "Each side in pixels has to be at least 1.", "There's no export option
    /// "colour".", "The quality has to be at most 1."
    static func plain(_ issue: SchemaIssue) -> String {
        let keys = issue.path.split(separator: "/").filter { Int($0) == nil }.map(String.init)
        if issue.message == "unexpected key" { return "There's no export option \"\(keys.joined(separator: "."))\"." }
        if keys == ["size", "pixels"], issue.message.hasSuffix("items") { return "Pixels takes two numbers, the width and the height." }
        let name = keys == ["size", "pixels"] ? "Each side in pixels" : keys.isEmpty ? "The options" : "The \(keys.joined(separator: " "))"
        let types = ["integer": "a whole number", "number": "a number", "string": "text", "boolean": "true or false",
                     "object": "an object", "array": "a list"]
        let wanted = issue.message.hasPrefix("expected ") ? String(issue.message.dropFirst("expected ".count)) : issue.message
        return "\(name) has to be \(types[wanted] ?? wanted)."
    }

    /// The size object's one mode: `{"scale": s}`, `{"pixels": [w, h], "stretch": b}` or `{"longEdge": n}`.
    private static func size(_ s: [String: JSONValue]) throws -> SuiteExportSize {
        let free = s["stretch"] == nil
        switch (s["scale"], s["pixels"], s["longEdge"]) {
        case (.number(let x)?, nil, nil) where free: return .scale(x)
        case (nil, nil, .number(let n)?) where free:
            if let n = Int(exactly: n) { return .longEdge(n) }
        case (nil, .array(let wh)?, nil):
            if wh.count == 2, case .number(let w)? = wh.first, case .number(let h)? = wh.last,
               let w = Int(exactly: w), let h = Int(exactly: h) {
                return .pixels(width: w, height: h, stretch: s["stretch"] == .bool(true))
            }
        default: break
        }
        throw ExportOptionRefusal.invalid("/size: give one of scale, pixels or longEdge; stretch goes with pixels.")
    }

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
    /// How the sheet's shape refusal ends; the CLI and MCP, which have no ratio lock, say `stretchHint` instead.
    public static let unlockHint = "Unlock the ratio to stretch.", stretchHint = #"Pass "stretch": true with pixels to stretch."#

    /// The longest side any export writes, in pixels.
    public static let maxSide = 16_384

    /// Exact output pixels for a scope `source` pixels big at 1x.
    public static func pixels(of source: (width: Int, height: Int), _ size: SuiteExportSize,
                              evenSize: Bool) throws -> (width: Int, height: Int) {
        guard source.width >= 1, source.height >= 1 else { throw refuse("The artwork has no size to export.") }
        let (sw, sh) = (Double(source.width), Double(source.height))
        var (w, h) = source
        switch size {
        case .scale(let s):
            guard s.isFinite, s > 0 else { throw refuse("A scale has to be more than 0.") }
            (w, h) = (whole(sw * s), whole(sh * s))
        case .longEdge(let n):
            guard n >= 1 else { throw refuse("The long edge needs at least 1 px.") }
            let short = whole(Double(n) * min(sw, sh) / max(sw, sh))
            (w, h) = source.width >= source.height ? (n, short) : (short, n)
        case .pixels(let pw, let ph, let stretch):
            guard pw >= 1, ph >= 1 else { throw refuse("A size needs at least 1 px on each side.") }
            guard pw <= maxSide, ph <= maxSide else { throw pastLimit(pw, ph) }
            if !stretch, !keepsShape(pw, ph, sw, sh) {
                throw refuse("\(pw) × \(ph) doesn't keep the artwork's \(ratio(source)) shape. \(unlockHint)")
            }
            (w, h) = (pw, ph)
        }
        guard w <= maxSide, h <= maxSide else { throw pastLimit(w, h) }
        (w, h) = (max(w, 1), max(h, 1))
        if evenSize { (w, h) = (max(w - w % 2, 2), max(h - h % 2, 2)) }
        return (w, h)
    }

    /// ImageIO property paths to drop ("{GPS}", "{Exif}.BodySerialNumber", "{MakerApple}", ...) and the XMP
    /// properties a sidecar leaves out ("exif:GPSLatitude", "xmp:CreateDate" under `.none`).
    public static func dropped(_ m: ExportMetadata) -> (properties: Set<String>, xmp: Set<String>) {
        switch m {
        case .all: ([], [])
        case .noLocation: (location, locationXMP)
        case .none: (location.union(rest), locationXMP.union(restXMP))
        }
    }

    /// Why these options can't run, or nil.
    public static func refusal(_ o: SuiteExportOptions, source: (width: Int, height: Int), formats: [ExportFormatSpec]) -> String? {
        guard let spec = formats.first(where: { $0.id == o.format }) else { return "There's no export format \"\(o.format)\"." }
        if spec.hasQuality, !(0...1).contains(o.quality) { return "Quality runs from 0 to 1." }
        if o.alpha, !spec.keepsAlpha {
            let other = formats.first { $0.kind == spec.kind && $0.keepsAlpha }
            return "\(spec.name) can't keep transparency." + (other.map { " Choose \($0.name)." } ?? "")
        }
        do {
            _ = try pixels(of: source, o.size, evenSize: spec.needsEvenSize)
            return nil
        } catch {
            return String(describing: error)
        }
    }

    /// Where the picture was made and what made it: GPS, IPTC place names, serial numbers, maker notes.
    static let location: Set<String> = ["{GPS}", "{IPTC}.City", "{IPTC}.SubLocation", "{IPTC}.Province/State",
        "{IPTC}.Country/PrimaryLocationCode", "{IPTC}.Country/PrimaryLocationName", "{Exif}.BodySerialNumber",
        "{Exif}.LensSerialNumber", "{ExifAux}.SerialNumber", "{Exif}.MakerNote", "{MakerApple}", "{MakerCanon}",
        "{MakerNikon}", "{MakerMinolta}", "{MakerFuji}", "{MakerOlympus}", "{MakerPentax}"]
    static let locationXMP: Set<String> = ["exif:GPSLatitude", "exif:GPSLongitude", "exif:GPSAltitude", "exif:GPSAltitudeRef",
        "exif:GPSTimeStamp", "exif:GPSImgDirection", "exif:GPSSpeed", "exif:GPSDestLatitude", "exif:GPSDestLongitude",
        "Iptc4xmpCore:Location", "photoshop:City", "photoshop:State", "photoshop:Country",
        "exifEX:BodySerialNumber", "exifEX:LensSerialNumber", "aux:SerialNumber"]
    /// Everything else `.none` drops: every dictionary but `{TIFF}.Orientation` and the colour profile.
    static let rest: Set<String> = ["{Exif}", "{ExifAux}", "{IPTC}", "{8BIM}", "{DNG}", "{CIFF}",
        "{TIFF}.Make", "{TIFF}.Model", "{TIFF}.Software", "{TIFF}.DateTime", "{TIFF}.Artist", "{TIFF}.Copyright",
        "{TIFF}.HostComputer", "{TIFF}.ImageDescription", "{PNG}.Author", "{PNG}.Copyright", "{PNG}.CreationTime",
        "{PNG}.Description", "{PNG}.Software", "{PNG}.Title", "{PNG}.Comment"]
    static let restXMP: Set<String> = ["xmp:CreateDate", "xmp:ModifyDate", "xmp:MetadataDate", "xmp:CreatorTool",
        "xmp:Rating", "xmp:Label", "dc:creator", "dc:rights", "dc:title", "dc:description", "dc:subject",
        "photoshop:DateCreated", "exif:DateTimeOriginal", "tiff:Make", "tiff:Model", "tiff:Artist"]

    /// True when `w` × `h` is the artwork's shape to within a pixel of rounding: one side is the other's
    /// proportional length rounded (`|w·sh − h·sw| ≤ max(sw, sh) / 2`).
    private static func keepsShape(_ w: Int, _ h: Int, _ sw: Double, _ sh: Double) -> Bool {
        abs(Double(w) * sh - Double(h) * sw) * 2 <= max(sw, sh)
    }

    /// `x` rounded to whole pixels; anything past the limit reads as one past it.
    private static func whole(_ x: Double) -> Int {
        let r = x.rounded()
        return r > Double(maxSide) ? maxSide + 1 : Int(r)
    }

    /// The artwork's shape in lowest terms ("4:5").
    private static func ratio(_ s: (width: Int, height: Int)) -> String {
        var (a, b) = (s.width, s.height)
        while b != 0 { (a, b) = (b, a % b) }
        let d = max(a, 1)
        return "\(s.width / d):\(s.height / d)"
    }

    private static func pastLimit(_ w: Int, _ h: Int) -> ExportOptionRefusal {
        refuse("\(w) × \(h) px is past the \(maxSide) px limit on a side.")
    }

    private static func refuse(_ why: String) -> ExportOptionRefusal { .invalid(why) }
}
