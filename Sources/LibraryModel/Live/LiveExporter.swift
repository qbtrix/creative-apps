// Live/LiveExporter.swift: J7's exporter (EX-2). `plan` sizes each photo at
// the options' long edge, never enlarged (nil keeps the photo's size), and
// names it through EX-1's rule (`ExportNaming.stem`, `ExportNames.unique`).
// `render` is one pipeline: a full-size decode (a sample's `SampleImage`,
// never decoded), a lanczos3 shrink so the cropped photo is about the planned
// long side (`preShrunk`: develop runs on the export's pixels, not the
// camera's), develop through `DevelopRendering` (tone, then crop), lanczos3
// down to the planned long side when the crop left more, sRGB bytes. Decode errors pass through.
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

    /// The photo's full-size pixels `b` shrunk, developed, then resized so the developed crop's long side is
    /// `longSide`: the export's picture before encoding, shared with the headless export.
    static func developed(_ b: PixelBuffer, photo: PhotoItem, longSide: Int,
                          develop: any DevelopRendering) throws -> PixelBuffer {
        let buffer = try develop.render(preShrunk(b, photo: photo, longSide: longSide), settings: photo.develop)
        // The developed buffer's shape is the real crop's; the plan sets the long side.
        let target = PixelSize(width: buffer.width, height: buffer.height).fitting(longSide: longSide)
        guard target.width != buffer.width || target.height != buffer.height else { return buffer }
        return try buffer.resized(width: target.width, height: target.height, filter: .lanczos3)
    }

    /// `b`, the photo's full-size pixels, shrunk by the planned long side over the cropped photo's (rounded as
    /// `PixelSize.fitting` rounds, so an uncropped photo lands on the plan's size); untouched at full size.
    static func preShrunk(_ b: PixelBuffer, photo: PhotoItem, longSide: Int) throws -> PixelBuffer {
        let full = croppedSize(photo).longSide
        guard full > longSide, longSide > 0 else { return b }
        let scale = Double(longSide) / Double(full)
        let w = max(Int((Double(b.width) * scale).rounded()), 1), h = max(Int((Double(b.height) * scale).rounded()), 1)
        guard w < b.width || h < b.height else { return b }
        return try b.resized(width: w, height: h, filter: .lanczos3)
    }

    /// The size the crop leaves of the oriented photo (EX-14 proves it), else the oriented photo's own.
    static func croppedSize(_ photo: PhotoItem) -> PixelSize {
        let faced = photo.orientedSize
        guard let crop = photo.develop.crop,
              let frame = try? LiveCrop().frame(crop, photo: faced),
              frame.width >= 1, frame.height >= 1 else { return faced }
        return PixelSize(width: frame.width, height: frame.height)
    }
}
