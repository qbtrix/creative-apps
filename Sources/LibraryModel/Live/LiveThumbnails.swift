// Live/LiveThumbnails.swift: the grid's thumbnails (feature thumbnails, TH-3).
// An actor: decode the file at twice the bucket (never above the photo),
// apply the develop settings, lanczos3 down to the bucket, and keep the
// result in an LRU of at most `ThumbnailBucket.cacheBytes`, keyed by id,
// long side and the develop token (`ThumbnailToken`), so changed settings
// never hit a stale picture. A photo with no path (a sample) is drawn from
// `SampleImage` at its crop's shape, like the fakes. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public actor LiveThumbnails: ThumbnailProviding {
    public static let unavailable: String? = nil

    struct Key: Hashable {
        let id: String
        let longSide: Int
        let token: Int
    }

    private struct Entry {
        let image: DisplayImage
        var lastUse: UInt64
    }

    let decoder: any PhotoDecoding
    let develop: any DevelopRendering
    let cacheLimit: Int
    private var cache: [Key: Entry] = [:]
    private var clock: UInt64 = 0
    /// Bytes of display images held in the cache; never above `cacheLimit` after a call.
    private(set) var cachedBytes = 0

    public init(decoder: any PhotoDecoding, develop: any DevelopRendering) {
        self.init(decoder: decoder, develop: develop, cacheLimit: ThumbnailBucket.cacheBytes)
    }

    init(decoder: any PhotoDecoding, develop: any DevelopRendering, cacheLimit: Int) {
        self.decoder = decoder; self.develop = develop; self.cacheLimit = cacheLimit
    }

    public func thumbnail(for photo: PhotoItem, longSide: Int) async throws -> DisplayImage {
        let side = max(longSide, 1)
        let key = Key(id: photo.id, longSide: side, token: ThumbnailToken.of(photo.develop, longSide: side))
        clock &+= 1
        if let hit = cache[key] {
            cache[key]?.lastUse = clock
            return hit.image
        }
        let image = try await render(photo, longSide: side)
        insert(image, for: key)
        return image
    }

    public func invalidate(_ id: String) async {
        for key in cache.keys where key.id == id {
            cachedBytes -= cache.removeValue(forKey: key)?.image.rgba8.count ?? 0
        }
    }

    /// The pipeline: decode, develop, lanczos3 to `longSide`, sRGB bytes.
    private func render(_ photo: PhotoItem, longSide: Int) async throws -> DisplayImage {
        guard let path = photo.path else {
            let shaped = FakeBehavior.cropShaped(photo, photo.develop.crop)
            guard let image = SampleImage.image(for: shaped, longSide: longSide) else {
                throw LibraryError.notAnImage(photo.id)
            }
            return image
        }
        let photoSide = photo.pixelSize.longSide
        let decodeSide = photoSide >= 1 ? min(2 * longSide, photoSide) : 2 * longSide
        let decoded = try await decoder.decode(path: path, maxLongSide: decodeSide)
        let target = decoded.size.fitting(longSide: longSide)
        // Neutral settings leave the pixels as they are (DevelopRendering), so
        // a decode already at the target size is the thumbnail.
        if photo.develop.isNeutral && target == decoded.size { return decoded }
        do {
            var buffer = try PixelBuffer(rgba8: decoded.rgba8, width: decoded.size.width,
                                         height: decoded.size.height, colorSpace: .sRGB)
            buffer = try develop.render(buffer, settings: photo.develop)
            let size = PixelSize(width: buffer.width, height: buffer.height).fitting(longSide: longSide)
            if size.width != buffer.width || size.height != buffer.height {
                buffer = try buffer.resized(width: size.width, height: size.height, filter: .lanczos3)
            }
            guard let image = DisplayImage(size: size, rgba8: try buffer.rgba8(colorSpace: .sRGB)) else {
                throw LibraryError.renderFailed("the thumbnail has no pixels")
            }
            return image
        } catch let error as LibraryError {
            throw error
        } catch {
            throw LibraryError.renderFailed(String(describing: error))
        }
    }

    /// Adds `image`, then drops the least recently used until the cache fits.
    private func insert(_ image: DisplayImage, for key: Key) {
        cachedBytes -= cache[key]?.image.rgba8.count ?? 0
        cache[key] = Entry(image: image, lastUse: clock)
        cachedBytes += image.rgba8.count
        while cachedBytes > cacheLimit, let oldest = cache.min(by: { $0.value.lastUse < $1.value.lastUse })?.key {
            cachedBytes -= cache.removeValue(forKey: oldest)?.image.rgba8.count ?? 0
        }
    }
}
