// Live/LiveExporter.swift: J7's exporter (EX-2). `plan` sizes each photo at
// the options' long edge, never enlarged (nil keeps the photo's size), and
// names it through EX-1's rule (`ExportNaming.stem`, `ExportNames.unique`).
// `render` is one pipeline: a decode a couple of pixels past the smallest size
// whose crop covers the plan (`decodeSide`; full size only when the plan is the
// photo's own size; a sample's `SampleImage`, never decoded), a lanczos3 shrink
// to exactly that smallest size (`preShrunk`: develop runs on the export's
// pixels, not the camera's, as the loupe's does on its decode), develop through `DevelopRendering` (tone,
// then crop), lanczos3 to exactly the plan's size when the crop left more, sRGB
// bytes. Decode errors pass through.
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
        let image = try await decoded(photo, longSide: item.size.longSide)
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

    /// The photo's upright pixels: a sample's gradient at full size, else the decode at `decodeSide`.
    private func decoded(_ photo: PhotoItem, longSide: Int) async throws -> DisplayImage {
        guard let path = photo.path else {
            guard let image = SampleImage.image(for: photo, longSide: nil) else {
                throw LibraryError.notAnImage(photo.id)
            }
            return image
        }
        return try await decoder.decode(path: path, maxLongSide: Self.decodeSide(photo, longSide: longSide))
    }

    /// The long side to decode at for a plan at `longSide`: two pixels past the smallest whose crop covers
    /// the plan, so the decoder does the big shrink (P8, #6205: a full-size decode then a CPU shrink took
    /// most of an export) and `preShrunk` only trims; nil (full size) when that is the photo's own.
    static func decodeSide(_ photo: PhotoItem, longSide: Int) -> Int? {
        guard croppedSize(photo).longSide > longSide, longSide > 0 else { return nil }
        let side = coveringSide(photo, longSide: longSide) + 2
        return side < photo.pixelSize.longSide ? side : nil
    }

    /// The photo's full-size pixels `b` shrunk, developed, then resized to the plan's size (the crop's size
    /// fitted to `longSide`): the export's picture before encoding, shared with the headless export.
    static func developed(_ b: PixelBuffer, photo: PhotoItem, longSide: Int,
                          develop: any DevelopRendering) throws -> PixelBuffer {
        let buffer = try develop.render(preShrunk(b, photo: photo, longSide: longSide), settings: photo.develop)
        let target = croppedSize(photo).fitting(longSide: longSide)
        guard target.width != buffer.width || target.height != buffer.height else { return buffer }
        return try buffer.resized(width: target.width, height: target.height, filter: .lanczos3)
    }

    /// `b`, the photo's pixels (full size, or `decodeSide`'s decode), shrunk to the smallest size on the
    /// photo's own grid whose crop covers the plan; untouched when it is already no bigger. `LiveCrop.frame`
    /// rounds at every step, so the crop of a shrunk photo can land a pixel or two under the plan's (1022 × 682
    /// for 1024 × 683): `coveringSide` grows a pixel at a time until it covers, so `developed` only ever shrinks.
    static func preShrunk(_ b: PixelBuffer, photo: PhotoItem, longSide: Int) throws -> PixelBuffer {
        let full = croppedSize(photo).longSide
        guard full > longSide, longSide > 0 else { return b }
        let size = photo.pixelSize.fitting(longSide: coveringSide(photo, longSide: longSide))
        guard size.width < b.width || size.height < b.height else { return b }
        return try b.resized(width: size.width, height: size.height, filter: .lanczos3)
    }

    /// The smallest long side of the photo whose crop covers the plan at `longSide`, from the plan's scale up
    /// a pixel at a time; the photo's own when nothing smaller does.
    static func coveringSide(_ photo: PhotoItem, longSide: Int) -> Int {
        let full = croppedSize(photo).longSide, planned = croppedSize(photo).fitting(longSide: longSide)
        let source = photo.pixelSize
        var side = Int((Double(source.longSide) * Double(longSide) / Double(full)).rounded())
        while side < source.longSide, !covers(planned, photo: photo, at: source.fitting(longSide: side)) { side += 1 }
        return side
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
