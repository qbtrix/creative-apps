// Live/LiveExporter.swift: J7's exporter (EX-2). `plan` sizes each photo at
// the options' long edge, never enlarged (nil keeps the photo's size), and
// names it through EX-1's rule (`ExportNaming.stem`, `ExportNames.unique`).
// `render` is one pipeline: a full-size decode (a sample's `SampleImage`,
// never decoded), develop through `DevelopRendering` (tone, then crop),
// lanczos3 to the planned long side, sRGB bytes. Decode errors pass through.
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
        let stems = photos.enumerated().map { index, photo in
            options.naming.stem(for: photo, index: index, count: photos.count)
        }
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
            var buffer = try PixelBuffer(rgba8: image.rgba8, width: image.size.width,
                                         height: image.size.height, colorSpace: .sRGB)
            buffer = try develop.render(buffer, settings: photo.develop)
            // The developed buffer's shape is the real crop's; the plan sets the long side.
            let target = PixelSize(width: buffer.width, height: buffer.height).fitting(longSide: item.size.longSide)
            if target.width != buffer.width || target.height != buffer.height {
                buffer = try buffer.resized(width: target.width, height: target.height, filter: .lanczos3)
            }
            guard let out = DisplayImage(size: target, rgba8: try buffer.rgba8(colorSpace: .sRGB)) else {
                throw LibraryError.renderFailed("the exported picture has no pixels")
            }
            return out
        } catch let error as LibraryError {
            throw error
        } catch {
            throw LibraryError.renderFailed(String(describing: error))
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

    /// The size the crop leaves (EX-14 proves it), else the photo's own.
    static func croppedSize(_ photo: PhotoItem) -> PixelSize {
        guard let crop = photo.develop.crop,
              let frame = try? LiveCrop().frame(crop, photo: photo.pixelSize),
              frame.width >= 1, frame.height >= 1 else { return photo.pixelSize }
        return PixelSize(width: frame.width, height: frame.height)
    }
}
