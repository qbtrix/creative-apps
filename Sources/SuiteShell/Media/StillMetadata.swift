// StillMetadata.swift: export-pack's live MetadataCarrying (XP-7), the
// `metadata` member of SuiteServices.live (wired in Live/MediaSlot.swift).
// An export encodes its still from pixels alone; this copies the source's
// metadata back onto it minus the property paths the policy drops
// (`ExportRules.dropped`: "{GPS}" drops a whole dictionary,
// "{Exif}.BodySerialNumber" one key). Structural keys that describe the
// source's own encoding (its JFIF and HEIF blocks, its pixel size) never
// move. The copy goes through SuiteImageIO, the one ImageIO adapter: first
// `CGImageDestinationCopyImageSource` with the source's tags for the kept
// properties, which leaves the still's compressed pixels and profile as they
// are; when that can't copy the format, or the copy lost a kept path, reads
// back another orientation value (a HEIC copy keeps the still's own 1, since
// HEIC reads orientation from its transform, not the TIFF tag) or lets a
// dropped path through, the still is encoded again at full quality with the
// kept properties, which sets that transform. An unreadable source copies
// nothing; an unreadable still throws `.readFailed`.
import Foundation
import SuiteModel

public struct StillMetadata: MetadataCarrying {
    public init() {}

    public func carrying(_ still: Data, from source: Data, dropping: Set<String>) throws(SuiteError) -> Data {
        let own = Self.paths(try SuiteImageIO.properties(still))
        guard let origin = try? SuiteImageIO.properties(source) else { return still }
        let kept = Self.kept(origin, dropping: dropping)
        let wanted = Self.paths(kept).union(own.intersection(["ProfileName"]))
        let orientation = kept["Orientation"] as? Int
        if let copy = SuiteImageIO.copyingTags(still, from: source, keeping: Self.pairs(kept)),
            let copied = try? SuiteImageIO.properties(copy), orientation == nil || copied["Orientation"] as? Int == orientation,
            case let got = Self.paths(copied),
            wanted.isSubset(of: got), !got.subtracting(own).contains(where: { Self.isDropped($0, dropping) }) {
            return copy
        }
        return try SuiteImageIO.reencoding(still, properties: kept)
    }

    public func properties(of image: Data) throws(SuiteError) -> Set<String> {
        Self.paths(try SuiteImageIO.properties(image))
    }

    /// Paths that describe the source's own encoding, so they never move onto the still.
    static let structural: Set<String> = ["{JFIF}", "{HEIF}", "{Exif}.PixelXDimension", "{Exif}.PixelYDimension",
                                          "{PNG}.Gamma", "{PNG}.InterlaceType", "{PNG}.sRGBIntent", "{PNG}.Chromaticities"]

    /// Every property path in `properties`: a dictionary as "{Exif}" and each of its keys as
    /// "{Exif}.DateTimeOriginal"; a top-level value by its own key ("Orientation", "ProfileName").
    static func paths(_ properties: [String: Any]) -> Set<String> {
        var paths = Set<String>()
        for (name, value) in properties {
            paths.insert(name)
            if name.hasPrefix("{"), let dictionary = value as? [String: Any] {
                for key in dictionary.keys { paths.insert("\(name).\(key)") }
            }
        }
        return paths
    }

    /// True when `path` is dropped by itself or by its whole dictionary.
    static func isDropped(_ path: String, _ dropping: Set<String>) -> Bool {
        if dropping.contains(path) { return true }
        guard let dot = path.firstIndex(of: "."), path.hasPrefix("{") else { return false }
        return dropping.contains(String(path[..<dot]))
    }

    /// The source's dictionaries minus the dropped and structural paths, plus its orientation.
    static func kept(_ properties: [String: Any], dropping: Set<String>) -> [String: Any] {
        var kept: [String: Any] = [:]
        for (name, value) in properties {
            guard name.hasPrefix("{"), let dictionary = value as? [String: Any],
                !dropping.contains(name), !structural.contains(name)
            else { continue }
            let keys = dictionary.filter { !dropping.contains("\(name).\($0.key)") && !structural.contains("\(name).\($0.key)") }
            if !keys.isEmpty { kept[name] = keys }
        }
        if let orientation = properties["Orientation"], !dropping.contains("Orientation") { kept["Orientation"] = orientation }
        return kept
    }

    /// Each kept dictionary key as a (dictionary, key) pair, orientation as TIFF's.
    static func pairs(_ kept: [String: Any]) -> [(dictionary: String, key: String)] {
        var pairs: [(dictionary: String, key: String)] = []
        for (name, value) in kept {
            guard let dictionary = value as? [String: Any] else { continue }
            for key in dictionary.keys { pairs.append((dictionary: name, key: key)) }
        }
        let tiffOrientation = pairs.contains { $0.dictionary == "{TIFF}" && $0.key == "Orientation" }
        if kept["Orientation"] != nil, !tiffOrientation {
            pairs.append((dictionary: "{TIFF}", key: "Orientation"))
        }
        return pairs
    }
}
