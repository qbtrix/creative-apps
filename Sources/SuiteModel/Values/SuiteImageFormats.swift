// SuiteImageFormats.swift: the suite's one list of image formats (shared-codecs
// SC-14). Every format any app reads, the four it writes, each one's type id,
// extensions and write bit depths. SuiteTypeRegistry's public rows, the
// plists, the panels, Library's scan and the CLI derive from it;
// FormatListRatchetTests keeps other lists out of Sources/. Foundation free,
// Linux-safe, Sendable.

/// One image format: an id the CLI, catalogs and ExportFormats share, and what the suite does with it.
public struct SuiteImageFormat: RawRepresentable, Hashable, Codable, Sendable {
    public enum Family: String, Sendable { case raster, highDynamicRange, cameraRaw }

    /// "tiff": the id the CLI, catalogs and ExportFormats use.
    public let rawValue: String
    /// "TIFF image": the type's name, as the registry and plists spell it.
    public let name: String
    /// "TIFF": the panels' and sheets' label.
    public let title: String
    public let typeID: SuiteTypeID
    /// Lower case, no dot; the first is the one written.
    public let extensions: [String]
    public let family: Family
    /// The bit depths the suite writes; empty for a read-only format.
    public let writeBitDepths: [Int]

    private init(_ id: String, _ title: String, name: String, type: String, extensions: [String],
                 family: Family = .raster, writes: [Int] = []) {
        rawValue = id; self.title = title; self.name = name; typeID = SuiteTypeID(rawValue: type)
        self.extensions = extensions; self.family = family; writeBitDepths = writes
    }

    /// The listed format with this id; nil for an id the registry doesn't list.
    public init?(rawValue: String) {
        guard let format = SuiteImageFormats.all.first(where: { $0.rawValue == rawValue }) else { return nil }
        self = format
    }

    /// The format a file name's extension names, in any case; nil without one or for an unlisted one.
    public init?(fileName: String) {
        guard let dot = fileName.lastIndex(of: "."), dot != fileName.startIndex else { return nil }
        let ext = fileName[fileName.index(after: dot)...].lowercased()
        guard let format = SuiteImageFormats.all.first(where: { $0.extensions.contains(ext) }) else { return nil }
        self = format
    }

    /// extensions[0]: the extension a written file gets.
    public var fileExtension: String { extensions.first ?? rawValue }

    public static func == (a: Self, b: Self) -> Bool { a.rawValue == b.rawValue }
    public func hash(into hasher: inout Hasher) { hasher.combine(rawValue) }

    /// Coded as its id alone; an unlisted id fails to decode.
    public init(from decoder: any Decoder) throws {
        let id = try decoder.singleValueContainer().decode(String.self)
        guard let format = SuiteImageFormat(rawValue: id) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "unknown image format \(id)"))
        }
        self = format
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public static let png = SuiteImageFormat("png", "PNG", name: "PNG image", type: "public.png",
                                             extensions: ["png"], writes: [8])
    public static let jpeg = SuiteImageFormat("jpeg", "JPEG", name: "JPEG image", type: "public.jpeg",
                                              extensions: ["jpg", "jpeg"], writes: [8])
    public static let heic = SuiteImageFormat("heic", "HEIC", name: "HEIC image", type: "public.heic",
                                              extensions: ["heic"], writes: [8])
    public static let heif = SuiteImageFormat("heif", "HEIF", name: "HEIF image", type: "public.heif",
                                              extensions: ["heif"])
    public static let tiff = SuiteImageFormat("tiff", "TIFF", name: "TIFF image", type: "public.tiff",
                                              extensions: ["tif", "tiff"], writes: [8, 16])
    public static let webp = SuiteImageFormat("webp", "WebP", name: "WebP image", type: "org.webmproject.webp",
                                              extensions: ["webp"])
    public static let gif = SuiteImageFormat("gif", "GIF", name: "GIF image", type: "com.compuserve.gif",
                                             extensions: ["gif"])
    public static let bmp = SuiteImageFormat("bmp", "BMP", name: "BMP image", type: "com.microsoft.bmp",
                                             extensions: ["bmp"])
    public static let exr = SuiteImageFormat("exr", "OpenEXR", name: "OpenEXR image", type: "com.ilm.openexr-image",
                                             extensions: ["exr"], family: .highDynamicRange)
    public static let tga = SuiteImageFormat("tga", "TGA", name: "TGA image", type: "com.truevision.tga-image",
                                             extensions: ["tga"])
    /// Every camera RAW extension in one row. ImageIO reads them today; suiteui/shared-raw adds the float decode.
    public static let cameraRaw = SuiteImageFormat(
        "raw", "Camera RAW", name: "Camera RAW image", type: "public.camera-raw-image",
        extensions: ["cr2", "cr3", "nef", "nrw", "arw", "sr2", "raf", "orf", "rw2", "dng", "pef", "srw",
                     "3fr", "iiq", "erf", "mos", "x3f"],
        family: .cameraRaw)
}

/// The registry of image formats.
public enum SuiteImageFormats {
    /// Read order for panels.
    public static let all: [SuiteImageFormat] = [.png, .jpeg, .heic, .heif, .tiff, .webp, .gif, .bmp, .exr, .tga, .cameraRaw]
    /// Every listed format is read.
    public static var readable: [SuiteImageFormat] { all }
    /// The formats written at some bit depth: png, jpeg, heic, tiff.
    public static var writable: [SuiteImageFormat] { all.filter { !$0.writeBitDepths.isEmpty } }
    /// Every extension `all` reads, lower case: an app's `openExtensions` and Library's scan.
    public static var readExtensions: [String] { all.flatMap(\.extensions) }
}
