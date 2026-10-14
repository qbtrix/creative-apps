// Fakes/FakeUseCases.swift: fakes of the use-case contracts. Each does the
// simplest honest thing (import returns the fixture, thumbnails and the
// loupe are gradients, develop changes nothing, crop centers the aspect,
// export plans by the same naming rule in a few lines) and obeys
// `-LibraryFakeMode`, so the UI track can show every state.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

public struct FakeImporter: PhotoImporting {
    let photos: [PhotoItem]
    let mode: FakeMode
    public init(photos: [PhotoItem], mode: FakeMode = .ok) {
        self.photos = photos; self.mode = mode
    }
    public func importFolder(_ folder: String, known: Set<String>,
                             progress: @escaping @Sendable (ImportProgress) -> Void) async throws -> ImportResult {
        try await FakeBehavior.perform(mode, failing: .unreadableFolder(folder))
        let fresh = photos.filter { !known.contains($0.id) }
        for index in fresh.indices { progress(ImportProgress(done: index, total: fresh.count)) }
        return ImportResult(added: fresh, alreadyKnown: photos.count - fresh.count, failures: [])
    }
}

public struct FakeThumbnails: ThumbnailProviding {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func thumbnail(for photo: PhotoItem, longSide: Int) async throws -> DisplayImage {
        try await FakeBehavior.perform(mode, failing: .notAnImage(photo.id))
        guard let image = FakeBehavior.gradient(for: photo, longSide: longSide) else {
            throw LibraryError.notAnImage(photo.id)
        }
        return image
    }
    public func invalidate(_ id: String) async {}
}

/// Applies changes like the live one but never advances (Auto Advance is the live rule).
public struct FakeCulling: PhotoCulling {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func apply(_ change: CullChange, to ids: Set<String>, in items: [PhotoItem]) throws -> [PhotoItem] {
        if mode == .fail { throw LibraryError.invalid("Rating is unavailable in this preview.") }
        if case .rating(let stars) = change, !(0...5).contains(stars) {
            throw LibraryError.invalid("A rating is 0 to 5 stars.")
        }
        return items.map { item in
            guard ids.contains(item.id) else { return item }
            var copy = item
            switch change {
            case .rating(let stars): copy.rating = stars
            case .flag(let flag): copy.flag = flag
            case .label(let label): copy.label = label
            }
            return copy
        }
    }
    public func advance(from id: String, before: [String], after: [String]) -> String? { id }
}

/// Stores ids and ratings only, as text: enough to drive the restore journey on fakes.
public struct FakeCatalogCoding: CatalogCoding {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func encode(_ photos: [PhotoItem]) throws -> Data {
        Data(photos.map { "\($0.id)\t\($0.rating)" }.joined(separator: "\n").utf8)
    }
    public func decode(_ data: Data) throws -> [PhotoItem] {
        if mode == .fail { throw LibraryError.damagedCatalog("fake") }
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n")
        return try lines.map { line in
            let fields = line.split(separator: "\t")
            guard fields.count == 2, let rating = Int(fields[1]) else { throw LibraryError.damagedCatalog("fake") }
            return PhotoItem(id: String(fields[0]), name: String(fields[0]), captureDate: Date(timeIntervalSince1970: 0),
                             color: .init(0.5, 0.5, 0.5), rating: rating)
        }
    }
}

public struct FakeLoupe: LoupeImaging {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func render(_ photo: PhotoItem, settings: DevelopSettings, longSide: Int,
                       quality: RenderQuality) async throws -> RenderedPhoto {
        try await FakeBehavior.perform(mode, failing: .renderFailed("the preview failed on purpose"))
        guard let image = FakeBehavior.gradient(for: photo, longSide: quality == .preview ? 512 : longSide) else {
            throw LibraryError.renderFailed("empty photo")
        }
        return RenderedPhoto(image: image, histogram: .empty, quality: quality)
    }
    public func prefetch(_ photos: [PhotoItem], longSide: Int) async {}
}

/// Returns the buffer unchanged and an empty histogram.
public struct FakeDevelop: DevelopRendering {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        if mode == .fail { throw LibraryError.renderFailed("the preview failed on purpose") }
        return buffer
    }
    public func histogram(of buffer: PixelBuffer) throws -> HistogramBins { .empty }
}

/// Centers the aspect on the photo and ignores the angle's shrink.
public struct FakeCrop: CropGeometry {
    public init() {}
    public func initial(aspect: CropAspect, angle: Double, photo: PixelSize) throws -> CropSettings {
        var rect = UnitRect.full
        if let ratio = aspect.ratio(for: photo), photo.height > 0 {
            let photoRatio = Double(photo.width) / Double(photo.height)
            if ratio < photoRatio { rect.width = ratio / photoRatio } else { rect.height = photoRatio / ratio }
            rect.x = (1 - rect.width) / 2
            rect.y = (1 - rect.height) / 2
        }
        return CropSettings(angle: min(max(angle, -45), 45), rect: rect, aspect: aspect)
    }
    public func dragged(_ crop: CropSettings, handle: CropHandle, dx: Double, dy: Double,
                        photo: PixelSize) throws -> CropSettings { crop }
    public func straightened(_ crop: CropSettings, angle: Double, photo: PixelSize) throws -> CropSettings {
        CropSettings(angle: min(max(angle, -45), 45), rect: crop.rect, aspect: crop.aspect)
    }
    public func frame(_ crop: CropSettings, photo: PixelSize) throws -> PixelRect {
        PixelRect(x: Int(crop.rect.x * Double(photo.width)), y: Int(crop.rect.y * Double(photo.height)),
                  width: max(Int(crop.rect.width * Double(photo.width)), 1),
                  height: max(Int(crop.rect.height * Double(photo.height)), 1))
    }
}

public struct FakeExporter: PhotoExporting {
    let mode: FakeMode
    public init(mode: FakeMode = .ok) { self.mode = mode }
    public func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan {
        var taken = existingNames
        let items = photos.map { photo -> ExportPlan.Item in
            var name = photo.name + ".jpg", n = 2
            while taken.contains(name) { name = photo.name + " \(n).jpg"; n += 1 }
            taken.insert(name)
            let size = options.longEdge.map { photo.pixelSize.fitting(longSide: $0) } ?? photo.pixelSize
            return ExportPlan.Item(photoID: photo.id, fileName: name, size: size)
        }
        return ExportPlan(items: items, options: options)
    }
    public func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage {
        try await FakeBehavior.perform(mode, failing: .renderFailed("the preview failed on purpose"))
        guard let image = FakeBehavior.gradient(for: photo, longSide: item.size.longSide) else {
            throw LibraryError.renderFailed("empty photo")
        }
        return image
    }
}
