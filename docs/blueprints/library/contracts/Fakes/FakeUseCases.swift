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
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
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
        var shaped = photo
        if let rect = photo.develop.crop?.rect {
            // The crop's shape, so a cropped photo's cell changes on fakes too.
            let size = PixelSize(width: max(Int(Double(photo.pixelSize.width) * rect.width), 1),
                                 height: max(Int(Double(photo.pixelSize.height) * rect.height), 1))
            shaped = photo.withSize(size)
        }
        guard let image = FakeBehavior.gradient(for: shaped, longSide: longSide) else {
            throw LibraryError.notAnImage(photo.id)
        }
        return image
    }
    public func invalidate(_ id: String) async {}
}

/// Applies changes like the live one; Auto Advance is the plain rule (the
/// next id in `before`, staying on the last) without the filter case.
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
    public func advance(from id: String, before: [String], after: [String]) -> String? {
        guard let index = before.firstIndex(of: id) else { return after.first }
        return index + 1 < before.count ? before[index + 1] : id
    }
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
        guard let base = FakeBehavior.gradient(for: photo, longSide: quality == .preview ? 512 : longSide) else {
            throw LibraryError.renderFailed("empty photo")
        }
        // Not the develop math: a visible stand-in so the UI track sees every
        // slider move. Each step of any slider brightens by one byte level.
        let lift = Int(DevelopSlider.allCases.map { settings.value($0) / $0.step / 100 }.reduce(0, +).rounded())
        var bytes = base.rgba8
        var red = [Int](repeating: 0, count: HistogramBins.binCount), green = red, blue = red
        for i in stride(from: 0, to: bytes.count, by: 4) {
            for c in 0..<3 { bytes[i + c] = UInt8(min(max(Int(bytes[i + c]) + lift, 0), 255)) }
            red[Int(bytes[i])] += 1; green[Int(bytes[i + 1])] += 1; blue[Int(bytes[i + 2])] += 1
        }
        guard let image = DisplayImage(size: base.size, rgba8: bytes) else { throw LibraryError.renderFailed("size") }
        let histogram = HistogramBins(red: red, green: green, blue: blue, shadowClipped: 0, highlightClipped: 0)
        return RenderedPhoto(image: image, histogram: histogram, quality: quality)
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

/// Centers the aspect on the photo; an angle shrinks the rect by
/// cos + sin of it (a stand-in for `straightenCrop`); handle drags move the
/// matching edges by the drag, clamped to the photo, ignoring the aspect.
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
                        photo: PixelSize) throws -> CropSettings {
        guard photo.width > 0, photo.height > 0 else { return crop }
        let ux = dx / Double(photo.width), uy = dy / Double(photo.height)
        var r = crop.rect
        switch handle {
        case .inside: r.x += ux; r.y += uy
        case .left, .topLeft, .bottomLeft: r.x += ux; r.width -= ux
        case .right, .topRight, .bottomRight: r.width += ux
        case .top, .bottom: break
        }
        switch handle {
        case .top, .topLeft, .topRight: r.y += uy; r.height -= uy
        case .bottom, .bottomLeft, .bottomRight: r.height += uy
        default: break
        }
        r.width = min(max(r.width, 0.01), 1); r.height = min(max(r.height, 0.01), 1)
        r.x = min(max(r.x, 0), 1 - r.width); r.y = min(max(r.y, 0), 1 - r.height)
        return CropSettings(angle: crop.angle, rect: r, aspect: crop.aspect)
    }
    public func straightened(_ crop: CropSettings, angle: Double, photo: PixelSize) throws -> CropSettings {
        let a = min(max(angle, -45), 45), radians = abs(a) * Double.pi / 180
        let shrink = 1 / (cos(radians) + sin(radians))
        var r = crop.rect
        let w = r.width * shrink, h = r.height * shrink
        r.x += (r.width - w) / 2; r.y += (r.height - h) / 2; r.width = w; r.height = h
        return CropSettings(angle: a, rect: r, aspect: crop.aspect)
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
