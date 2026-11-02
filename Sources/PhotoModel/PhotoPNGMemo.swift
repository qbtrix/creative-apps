// PhotoPNGMemo.swift: a window autosave's memory of the PNG it last wrote for each layer and mask (#5312), so the
// write after one stroke encodes only the layer the stroke changed, not every layer. Kept per key (the layer or
// mask) beside the tiles it was made from: a later write reuses the PNG only while the tiles are equal, and a copy
// of a layer shares its tiles' storage, so an unchanged layer compares by storage, not pixel by pixel. Each write
// hands the archive a codec (`Write`) that answers the snapshot's own image of an unchanged layer, matched by the
// image's buffer and never by its pixels, with the kept PNG, and encodes everything else through the window's
// codec; what that write used becomes the memory. Holds the PNGs and shares the layers' tiles, nothing else.
// Thread-safe. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Synchronization

public final class PhotoPNGMemo: Sendable {
    private let kept = Mutex([String: Kept]())

    public init() {}

    struct Kept: Sendable {
        let tiles: TiledPixels
        let png: Data
    }

    /// `workspace`'s document package through `archive`, each layer or mask whose tiles the last write saw
    /// written as the PNG it made then, the rest through `codec`; what this write used is kept for the next.
    func package(of workspace: PhotoWorkspace, archive: any DocumentArchiving, codec: any PhotoImageCodec) throws -> PhotoPackage {
        let before = kept.withLock { $0 }
        var known: [Write.Known] = []
        let snapshot = try workspace.snapshot { key, tiles in
            let image = try PhotoWorkspace.decoded(tiles)
            let png = before[key].flatMap { $0.tiles == tiles ? $0.png : nil }
            known.append(Write.Known(key: key, tiles: tiles, image: image, png: png))
            return image
        }
        let write = Write(base: codec, known: known)
        let package = try archive.encode(snapshot, codec: write)
        kept.withLock { $0 = write.used }
        return package
    }

    /// One write's codec: an image of `known` comes back as its kept PNG, or is encoded through `base` once and
    /// noted; any other image (the merged picture, the thumbnail) goes to `base`.
    final class Write: PhotoImageCodec {
        struct Known: Sendable {
            let key: String
            let tiles: TiledPixels
            let image: DecodedImage
            let png: Data?
        }

        let base: any PhotoImageCodec
        let known: [Known]
        private let made = Mutex([String: Data]())

        init(base: any PhotoImageCodec, known: [Known]) { self.base = base; self.known = known }

        var readExtensions: Set<String> { base.readExtensions }

        func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage { try base.decode(data, longestSide: longestSide) }

        func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
            guard format == .png, let match = known.first(where: { Self.same($0.image.rgba8, image.rgba8) }) else {
                return try base.encode(image, as: format, quality: quality)
            }
            if let png = match.png { return png }
            let png = try base.encode(image, as: format, quality: quality)
            made.withLock { $0[match.key] = png }
            return png
        }

        /// What this write kept or made for each key, beside its tiles.
        var used: [String: Kept] {
            let made = made.withLock { $0 }
            var used: [String: Kept] = [:]
            for k in known {
                if let png = k.png ?? made[k.key] { used[k.key] = Kept(tiles: k.tiles, png: png) }
            }
            return used
        }

        /// Whether `a` and `b` are the same buffer (a copy of one array), not merely equal bytes.
        private static func same(_ a: [UInt8], _ b: [UInt8]) -> Bool {
            a.withUnsafeBufferPointer { x in b.withUnsafeBufferPointer { y in x.count > 0 && x.baseAddress == y.baseAddress && x.count == y.count } }
        }
    }
}
