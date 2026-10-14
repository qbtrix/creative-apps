// Contracts/LibraryContracts.swift: one protocol per use case, so the UI
// track builds on the fakes while the logic track builds the live
// conformances. Three are platform contracts (decode, JPEG write, catalog
// file), conformed to in LibraryApp/Platform; the rest are conformed to in
// LibraryModel/Live over CoreRaster. Every async call runs off the main
// actor and returns a value the window hands to a LibraryCatalog method.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

// MARK: Platform (conformed to in LibraryApp/Platform, ImageIO and the file system)

/// Reads image files. Live: `ImageIODecoder`. Fake: `FakeDecoder`.
public protocol PhotoDecoding: Sendable {
    /// Image files under `folder`, subfolders included, hidden files and
    /// packages skipped, with their metadata; no pixels are decoded.
    /// Throws `LibraryError.unreadableFolder` when the folder can't be listed.
    func scan(folder: String) async throws -> FolderScan
    /// The file's pixels with its Exif orientation applied, converted to
    /// sRGB, long side at most `maxLongSide` (nil: full size), never enlarged.
    /// Throws `missingFile` or `notAnImage`.
    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage
}

/// Writes JPEG files. Live: `JPEGWriter`. Fake: `FakeJPEGWriter` (in memory).
public protocol JPEGWriting: Sendable {
    /// File names already in `folder`; throws `writeFailed` when it can't be listed.
    func existingNames(in folder: String) async throws -> Set<String>
    /// Writes `image` as an sRGB JPEG at `quality` (0...100) to `folder`/`fileName`.
    /// Never overwrites: throws `writeFailed` when the file exists or can't be written.
    func write(_ image: DisplayImage, quality: Int, folder: String, fileName: String) async throws
}

/// Where the catalog file lives. Live: `CatalogStore` (Application Support,
/// or `-LibraryCatalogDir`). Fake: `FakeCatalogStore` (in memory).
public protocol CatalogStoring: Sendable {
    /// The file's bytes; nil when there is no catalog yet.
    func read() async throws -> Data?
    /// Replaces the file atomically (write to a temporary file, then rename).
    func write(_ data: Data) async throws
    /// Renames the file to `catalog.json.bad` (replacing an older `.bad`), so
    /// the next write starts fresh; returns the new name.
    func setAside() async throws -> String
}

// MARK: Use cases (conformed to in LibraryModel/Live)

/// J1. Import a folder. Live: `LiveImporter(decoder:)`.
public protocol PhotoImporting: Sendable {
    /// Scans `folder`, skips paths in `known`, and returns the new photos in
    /// capture-date order with ids equal to their paths. Calls `progress`
    /// after each file, at most 30 times a second. Throws
    /// `unreadableFolder`, or `noPhotos` when the folder holds no image file
    /// at all; a file that fails is a `FileFailure`, never a throw.
    func importFolder(_ folder: String, known: Set<String>,
                      progress: @escaping @Sendable (ImportProgress) -> Void) async throws -> ImportResult
}

/// J2. Grid thumbnails. Live: `LiveThumbnails(decoder:develop:)`, an actor
/// with an LRU of `ThumbnailBucket.cacheLimit` images.
public protocol ThumbnailProviding: Sendable {
    /// The photo at `longSide` (a bucket: 128, 256 or 512) with its develop
    /// settings and crop applied. Throws `missingFile` or `notAnImage`.
    func thumbnail(for photo: PhotoItem, longSide: Int) async throws -> DisplayImage
    /// Drops cached images of `id` (after its settings change).
    func invalidate(_ id: String) async
}

/// J4. Rating, flag and label. Live: `LiveCulling`. Pure and synchronous: it
/// runs on the main actor inside a catalog method.
public protocol PhotoCulling: Sendable {
    /// `items` with `change` applied to every photo whose id is in `ids`;
    /// the rest unchanged and in the same order. Throws
    /// `LibraryError.invalid` for a rating outside 0...5, changing nothing.
    func apply(_ change: CullChange, to ids: Set<String>, in items: [PhotoItem]) throws -> [PhotoItem]
    /// Auto Advance: the photo to focus after a change to `id`. `before` is
    /// the shown order before the change and `after` the order after it (a
    /// filter may hide the photo). The next photo after `id`; if `id` is no
    /// longer shown, the photo that took its place; `id` itself when it was
    /// last; nil when nothing is shown.
    func advance(from id: String, before: [String], after: [String]) -> String?
}

/// J8, J9. The catalog file. Live: `LiveCatalogCoding` (JSON, `"version": 1`).
public protocol CatalogCoding: Sendable {
    func encode(_ photos: [PhotoItem]) throws -> Data
    /// Throws `damagedCatalog` for bytes that aren't a v1 catalog and
    /// `newerCatalog` for a version above 1. A missing `develop` object
    /// decodes as neutral settings.
    func decode(_ data: Data) throws -> [PhotoItem]
}

/// J3, J5. The loupe's picture. Live: `LiveLoupeImaging(decoder:develop:)`,
/// an actor caching the decoded screen-size buffers of the focused photo and
/// its two neighbours.
public protocol LoupeImaging: Sendable {
    /// `photo` with `settings` (tone and crop), long side at most `longSide`,
    /// and its histogram. `.preview` renders from the 512 px thumbnail decode
    /// (used during a drag); `.full` from the screen-size decode.
    func render(_ photo: PhotoItem, settings: DevelopSettings, longSide: Int,
                quality: RenderQuality) async throws -> RenderedPhoto
    /// Decodes `photos` ahead (the neighbours of the focused photo).
    func prefetch(_ photos: [PhotoItem], longSide: Int) async
}

/// J5, J7. Develop settings to pixels. Live: `LiveDevelop` over CoreRaster:
/// white balance, exposure, contrast, highlights and shadows in that order,
/// then the crop. Neutral settings return the buffer unchanged.
public protocol DevelopRendering: Sendable {
    func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer
    func histogram(of buffer: PixelBuffer) throws -> HistogramBins
}

/// J6. Crop geometry. Live: `LiveCrop` over CoreRaster's `straightenCrop`.
public protocol CropGeometry: Sendable {
    /// A crop at `aspect` and `angle`, centered and as large as fits.
    func initial(aspect: CropAspect, angle: Double, photo: PixelSize) throws -> CropSettings
    /// `crop` after dragging `handle` by `dx`, `dy` photo pixels, kept on its
    /// aspect and inside the straightened photo; at least 16 px a side.
    func dragged(_ crop: CropSettings, handle: CropHandle, dx: Double, dy: Double,
                 photo: PixelSize) throws -> CropSettings
    /// `crop` at a new angle, shrunk if needed to stay inside.
    func straightened(_ crop: CropSettings, angle: Double, photo: PixelSize) throws -> CropSettings
    /// The crop's frame in the straightened photo's pixels (what export writes).
    func frame(_ crop: CropSettings, photo: PixelSize) throws -> PixelRect
}

/// J7. Export. Live: `LiveExporter(decoder:develop:)`.
public protocol PhotoExporting: Sendable {
    /// Sizes and file names for `photos`: long edge from `options`, never
    /// enlarged; `<name>.jpg`, then `<name> 2.jpg`, ... skipping
    /// `existingNames` and names earlier in the plan.
    func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan
    /// One planned photo at full size with its settings, resized with
    /// lanczos3 to `item.size`. Throws `missingFile`, `notAnImage` or `renderFailed`.
    func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage
}

// MARK: Values the contracts above take

/// One culling change.
public enum CullChange: Hashable, Sendable {
    case rating(Int)
    case flag(PhotoFlag)
    case label(PhotoLabel?)

    /// The undo step's name: "Set Rating", "Pick", "Reject", "Clear Flag", "Set Label".
    public var undoName: String {
        switch self {
        case .rating: "Set Rating"
        case .flag(.pick): "Pick"
        case .flag(.reject): "Reject"
        case .flag(.none): "Clear Flag"
        case .label: "Set Label"
        }
    }
}

public struct ExportOptions: Hashable, Sendable {
    public static let defaultLongEdge = 2048
    public static let longEdgeRange = 16...16384
    /// Nil: original size.
    public var longEdge: Int?
    public var quality: Int
    public var folder: String
    /// `longEdge` and `quality` clamped to their ranges.
    public init(longEdge: Int? = defaultLongEdge, quality: Int = 85, folder: String) {
        self.longEdge = longEdge.map { min(max($0, Self.longEdgeRange.lowerBound), Self.longEdgeRange.upperBound) }
        self.quality = min(max(quality, 0), 100)
        self.folder = folder
    }
}

public struct ExportPlan: Hashable, Sendable {
    public struct Item: Hashable, Sendable {
        public var photoID: String
        public var fileName: String
        public var size: PixelSize
        public init(photoID: String, fileName: String, size: PixelSize) {
            self.photoID = photoID; self.fileName = fileName; self.size = size
        }
    }
    public var items: [Item]
    public var options: ExportOptions
    public init(items: [Item], options: ExportOptions) {
        self.items = items; self.options = options
    }
}
