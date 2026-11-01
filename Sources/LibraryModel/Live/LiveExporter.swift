// Live/LiveExporter.swift: J7's exporter (EX-2). `plan` sizes each photo at
// the options' long edge, never enlarged (nil keeps the photo's size), and
// names it through EX-1's rule (`ExportNaming.stem`, `ExportNames.unique`).
// `render` is one pipeline: a full-size decode (a sample's `SampleImage`,
// never decoded), a lanczos3 shrink to the smallest size whose crop covers the
// plan (`preShrunk`: develop runs on the export's pixels, not the camera's, as
// the loupe's does on its decode), develop through `DevelopRendering` (tone,
// then crop), lanczos3 to exactly the plan's size when the crop left more, sRGB
// bytes. Both lanczos3 resizes run across the cores (`LiveResize`, the same
// pixels as core's `resized`). Decode errors pass through.
// Each item carries the properties the options' metadata policy drops, for
// the writer (export-pack, LX-3).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel

public struct LiveExporter: PhotoExporting {
    public static let unavailable: String? = nil
    let decoder: any PhotoDecoding
    let develop: any DevelopRendering
    public init(decoder: any PhotoDecoding, develop: any DevelopRendering) {
        self.decoder = decoder; self.develop = develop
    }

    public func plan(_ photos: [PhotoItem], options: ExportOptions, existingNames: Set<String>) -> ExportPlan {
        let stems = options.naming.stems(for: photos)
        let names = ExportNames.unique(stems: stems, format: options.format, sidecar: options.sidecar,
                                       existing: existingNames)
        let dropping = ExportRules.dropped(options.metadata).properties
        var items: [ExportPlan.Item] = []
        items.reserveCapacity(photos.count)
        for (photo, name) in zip(photos, names) {
            let full = Self.croppedSize(photo)
            let size = options.longEdge.map { full.fitting(longSide: $0) } ?? full
            items.append(ExportPlan.Item(photoID: photo.id, fileName: name, size: size, dropping: dropping))
        }
        return ExportPlan(items: items, options: options)
    }

    public func render(_ item: ExportPlan.Item, photo: PhotoItem) async throws -> DisplayImage {
        let image = try await fullSize(photo)
        do {
            let full = try PixelBuffer(rgba8: image.rgba8, width: image.size.width,
                                       height: image.size.height, colorSpace: .sRGB)
            let buffer = try Self.developed(full, photo: photo, longSide: item.size.longSide, develop: develop)
            let target = PixelSize(width: buffer.width, height: buffer.height)
            guard let out = DisplayImage(size: target, rgba8: try buffer.rgba8(colorSpace: .sRGB)) else {
                throw LibraryError.renderFailed("the exported picture has no pixels")
            }
            return out
        } catch let error as LibraryError {
            throw error
        } catch {
            throw LibraryError.renderFailed("the picture couldn't be drawn at the export size")
        }
    }

    /// The photo's upright pixels at full size: a sample's gradient, else the decode.
    private func fullSize(_ photo: PhotoItem) async throws -> DisplayImage {
        guard let path = photo.path else {
            guard let image = SampleImage.image(for: photo, longSide: nil) else {
                throw LibraryError.notAnImage(photo.id)
            }
            return image
        }
        return try await decoder.decode(path: path, maxLongSide: nil)
    }

    /// The photo's full-size pixels `b` shrunk, developed, then resized to the plan's size (the crop's size
    /// fitted to `longSide`): the export's picture before encoding, shared with the headless export.
    static func developed(_ b: PixelBuffer, photo: PhotoItem, longSide: Int,
                          develop: any DevelopRendering) throws -> PixelBuffer {
        let buffer = try develop.render(preShrunk(b, photo: photo, longSide: longSide), settings: photo.develop)
        let target = croppedSize(photo).fitting(longSide: longSide)
        guard target.width != buffer.width || target.height != buffer.height else { return buffer }
        return try LiveResize.resized(buffer, width: target.width, height: target.height)
    }

    /// `b`, the photo's full-size pixels, shrunk so its crop is about the planned long side; untouched at full
    /// size. `LiveCrop.frame` rounds at every step, so the crop of a shrunk photo can land a pixel or two under
    /// the plan's (1022 × 682 for 1024 × 683): the shrink grows a pixel at a time until its crop covers the
    /// plan, so `developed` only ever shrinks to it.
    static func preShrunk(_ b: PixelBuffer, photo: PhotoItem, longSide: Int) throws -> PixelBuffer {
        let full = croppedSize(photo).longSide
        guard full > longSide, longSide > 0 else { return b }
        let planned = croppedSize(photo).fitting(longSide: longSide), source = PixelSize(width: b.width, height: b.height)
        var side = Int((Double(source.longSide) * Double(longSide) / Double(full)).rounded())
        while side < source.longSide, !covers(planned, photo: photo, at: source.fitting(longSide: side)) { side += 1 }
        let size = source.fitting(longSide: side)
        guard size.width < b.width || size.height < b.height else { return b }
        return try LiveResize.resized(b, width: size.width, height: size.height)
    }

    /// Whether `photo` drawn at `size` (its pixels before orientation) crops to at least `planned` both ways.
    private static func covers(_ planned: PixelSize, photo: PhotoItem, at size: PixelSize) -> Bool {
        let cut = croppedSize(photo, at: size)
        return cut.width >= planned.width && cut.height >= planned.height
    }

    /// The size the crop leaves of the oriented photo (EX-14 proves it), else the oriented photo's own.
    static func croppedSize(_ photo: PhotoItem) -> PixelSize { croppedSize(photo, at: photo.pixelSize) }

    /// `croppedSize` for the photo's pixels drawn at `size` (before orientation), as develop crops them.
    static func croppedSize(_ photo: PhotoItem, at size: PixelSize) -> PixelSize {
        let o = photo.develop.orientation.size(size.width, size.height)
        let faced = PixelSize(width: o.width, height: o.height)
        guard let crop = photo.develop.crop,
              let frame = try? LiveCrop().frame(crop, photo: faced),
              frame.width >= 1, frame.height >= 1 else { return faced }
        return PixelSize(width: frame.width, height: frame.height)
    }
}
