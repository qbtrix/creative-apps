// Live/LiveLoupeImaging.swift: the loupe's picture (J3, J5). Decodes through
// `PhotoDecoding` at the screen size (`.full`) or 512 px (`.preview`),
// develops through `DevelopRendering` and takes its histogram. An actor that
// keeps the decodes of the last three photos it rendered or prefetched (the
// focused photo and its two neighbours; QB-LIB-8), so stepping to a
// prefetched neighbour decodes nothing. A photo with no `path` (a sample) is
// drawn from `SampleImage`, never decoded or cached. Neutral settings hand
// the decode back unchanged; develop only takes the histogram. On the GPU
// route (`gpuFrame`, suite-imaging IM-11) the view draws the decoded base
// through `LiveDevelop.steps` itself; the actor still decodes and takes the
// histogram, from the preview decode developed on the CPU.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import CoreRender
import SuiteImaging

/// The loupe's picture on the GPU route: the undeveloped decode, the develop
/// steps the view writes over it (with the display steps last), and the
/// developed picture's histogram.
public struct LoupeGPUFrame: Equatable, Sendable {
    public var base: DisplayImage
    public var steps: [ToneAdjustment]
    public var histogram: HistogramBins
}

public actor LiveLoupeImaging: LoupeImaging {
    public static let unavailable: String? = nil
    /// The photos whose decodes are kept: the focused one and its two neighbours.
    static let cachedPhotos = 3
    /// The long side a `.preview` decodes at.
    static let previewLongSide = 512

    /// One photo's decodes: the screen-size one (with the long side it was
    /// asked at) and the 512 px preview.
    private struct Decodes {
        var full: (longSide: Int, image: DisplayImage)?
        var preview: DisplayImage?
    }

    let decoder: any PhotoDecoding
    let develop: any DevelopRendering
    /// Least recently used first; at most `cachedPhotos`.
    private var order: [String] = []
    private var cache: [String: Decodes] = [:]

    public init(decoder: any PhotoDecoding, develop: any DevelopRendering) {
        self.decoder = decoder; self.develop = develop
    }

    /// The ids of the photos whose decodes are held, least recently used first.
    var cachedPhotoIDs: [String] { order }

    public func render(_ photo: PhotoItem, settings: DevelopSettings, longSide: Int,
                       quality: RenderQuality) async throws -> RenderedPhoto {
        let side = quality == .preview ? Self.previewLongSide : longSide
        let base = try await decoded(photo, longSide: side, quality: quality)
        do {
            let buffer = try PixelBuffer(rgba8: base.rgba8, width: base.size.width, height: base.size.height)
            if settings.isNeutral {
                return RenderedPhoto(image: base, histogram: try develop.histogram(of: buffer), quality: quality)
            }
            let developed = try develop.render(buffer, settings: settings)
            let size = PixelSize(width: developed.width, height: developed.height)
            guard let image = DisplayImage(size: size, rgba8: try developed.rgba8()) else {
                throw LibraryError.renderFailed("the developed picture has no pixels")
            }
            return RenderedPhoto(image: image, histogram: try develop.histogram(of: developed), quality: quality)
        } catch let error as LibraryError {
            throw error
        } catch {
            throw LibraryError.renderFailed(String(describing: error))
        }
    }

    /// The GPU route's frame for `photo` at `longSide`; nil keeps the CPU
    /// route (`render`): the View > Rendering choice is CPU (`preferGPU`
    /// false), the settings carry a crop, or a step isn't on Metal yet. The
    /// histogram is the 512 px preview's, developed on the CPU, so a step
    /// never reads the GPU picture back. A waiting slider throws its reason.
    public func gpuFrame(_ photo: PhotoItem, settings: DevelopSettings, longSide: Int,
                         preferGPU: Bool) async throws -> LoupeGPUFrame? {
        guard settings.crop == nil else { return nil }
        for slider in DevelopSlider.allCases where settings.value(slider) != 0 {
            if let why = LiveDevelop.waiting[slider] { throw LibraryError.renderFailed(why) }
        }
        guard let steps = LiveDevelop.steps(for: settings),
              ImagingRoute.choose(preferGPU: preferGPU, steps: steps) == .gpu else { return nil }
        let base = try await decoded(photo, longSide: longSide, quality: .full)
        let developed = try await render(photo, settings: settings, longSide: longSide, quality: .preview)
        return LoupeGPUFrame(base: base, steps: steps, histogram: developed.histogram)
    }

    public func prefetch(_ photos: [PhotoItem], longSide: Int) async {
        for photo in photos where photo.path != nil {
            _ = try? await decoded(photo, longSide: longSide, quality: .full)
        }
    }

    /// The photo's pixels at `longSide`: a sample's `SampleImage`, a cached
    /// decode, or a new decode that joins the cache.
    private func decoded(_ photo: PhotoItem, longSide: Int, quality: RenderQuality) async throws -> DisplayImage {
        guard let path = photo.path else {
            guard let image = SampleImage.image(for: photo, longSide: longSide) else {
                throw LibraryError.renderFailed("the sample has no pixels")
            }
            return image
        }
        if let hit = cached(photo.id, longSide: longSide, quality: quality) {
            touch(photo.id)
            return hit
        }
        let image = try await decoder.decode(path: path, maxLongSide: longSide)
        var entry = cache[photo.id] ?? Decodes()
        switch quality {
        case .preview: entry.preview = image
        case .full: entry.full = (longSide, image)
        }
        cache[photo.id] = entry
        touch(photo.id)
        return image
    }

    private func cached(_ id: String, longSide: Int, quality: RenderQuality) -> DisplayImage? {
        guard let entry = cache[id] else { return nil }
        switch quality {
        case .preview: return entry.preview
        case .full: return entry.full.flatMap { $0.longSide == longSide ? $0.image : nil }
        }
    }

    /// Marks `id` most recently used and drops the oldest photos past the limit.
    private func touch(_ id: String) {
        order.removeAll { $0 == id }
        order.append(id)
        while order.count > Self.cachedPhotos {
            cache[order.removeFirst()] = nil
        }
    }
}
