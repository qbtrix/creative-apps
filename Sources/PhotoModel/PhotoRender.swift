// PhotoRender.swift: how Photo turns its layers into the picture. A region of
// the canvas renders by compositing the visible layers bottom-up, each through
// PhotoLayerComposite (a pixel layer at its offset with its blend mode and
// opacity, CoreRaster's composite; an adjustment layer passes through), then
// running the enabled adjustments in order: the tone section's unsharp pass,
// then SuiteImaging's ImagingProgram steps (tone's own, exposure, levels,
// curves, hue/saturation), then blur. Levels and curves work on display (sRGB-encoded)
// values, as photo editors' tone tools do (CoreRaster's ToneEncoding.sRGB),
// so mid grey sits near 0.5 on their axes; exposure stays linear. The blur and the unsharp pass read a margin of 3 sigma around the region,
// so a region renders exactly as the same pixels of the whole image would.
// `composite()` is the whole image at full size (export, tests); PhotoRenderer
// turns a workspace into display bytes (sRGB, straight alpha) tile by tile, in
// parallel, redrawing only the tiles that changed since the frame before
// (PhotoWorkspace.damage(since:)) and timing itself for the status line. The
// curve editor's line (`curveSamples`) runs the same CoreRaster curve over a
// ramp, and its histogram (`curvesHistogram`, the suite's ToneHistogram, which
// Levels draws too) counts the display values of 256 sampled rows of the image
// as it enters Curves, so both show what the render does; `curvesHistogramKey`
// changes exactly when that count can, and `curvesHistogram(composites:)` keeps
// each row's composite in a PhotoCompositeCache so a count after a tone edit
// composites no layer. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteImaging
import SuiteModel

/// One rendered picture: display bytes for the canvas, the revision they show
/// and how long the render took.
public struct PhotoFrame: Sendable, Equatable {
    public let width: Int
    public let height: Int
    /// width x height x 4 bytes, row-major, sRGB, straight alpha.
    public let rgba8: [UInt8]
    public let revision: Int
    public let milliseconds: Double
}

extension AdjustmentSettings {
    /// Pixels the blur reads beyond a region: its kernel radius, 3 sigma.
    var blurMargin: Int {
        isEnabled(.blur) && blurSigma > 0 ? Int((3 * blurSigma).rounded(.up)) : 0
    }

    /// Pixels a region reads beyond itself: the blur's margin or the tone
    /// section's unsharp radius, ceil(3 sigma), whichever is wider.
    var readMargin: Int {
        max(blurMargin, unsharp.map { Int((3 * $0.sigma).rounded(.up)) } ?? 0)
    }

    /// The enabled adjustments applied to `buffer`, in order: the tone
    /// section's unsharp pass (`unsharp`), then ImagingProgram's steps
    /// (`imagingSteps`: tone's own first, each section skipped at its
    /// identity), then the blur. The canvas draws in the same order.
    func applied(to buffer: PixelBuffer) throws -> PixelBuffer {
        try applied(to: buffer, sharpening: unsharp)
    }

    /// `applied(to:)` with `sharpening` as the unsharp pass, nil for none.
    func applied(
        to buffer: PixelBuffer, sharpening: (amount: Double, sigma: Double, threshold: Double)?
    ) throws -> PixelBuffer {
        var result = buffer
        if let s = sharpening { result = try result.unsharpMask(amount: s.amount, sigma: s.sigma, threshold: s.threshold) }
        result = try runImaging(imagingSteps, on: result)
        if blurMargin > 0 { result = try result.gaussianBlur(sigma: blurSigma) }
        return result
    }

    /// Exposure then levels, where enabled: the image Curves maps.
    func appliedBeforeCurves(to buffer: PixelBuffer) throws -> PixelBuffer {
        try runImaging(imagingSteps([.exposure, .levels]), on: buffer)
    }

    /// The tone curve at `count` evenly spaced display values from 0 through 1,
    /// worked out by CoreRaster's `curves(points:)` on a `count`-pixel ramp of
    /// those values themselves (the render applies the same curve to encoded
    /// values), so the editor draws exactly the curve the render applies.
    /// Empty for a `count` under 2.
    public func curveSamples(count: Int = 256) -> [CurvePoint] {
        guard count >= 2, var ramp = try? PixelBuffer(width: count, height: 1) else { return [] }
        let xs = (0..<count).map { Float($0) / Float(count - 1) }
        // Every grey is finite and in the buffer, so setPixel can't fail. The
        // curve fails only when steep enough to overflow a Float, and then the
        // render fails too; the editor draws no line.
        for (i, x) in xs.enumerated() { try? ramp.setPixel(x: i, y: 0, RGBA(r: x, g: x, b: x, a: 1)) }
        guard let curved = try? ramp.curves(points: curvePoints) else { return [] }
        return xs.enumerated().compactMap { i, x in (try? curved.pixel(x: i, y: 0)).map { CurvePoint(x: x, y: $0.r) } }
    }
}

extension PhotoWorkspace {
    /// The whole image as export and the canvas show it: every visible layer
    /// composited, then the adjustments. Throws `RasterError.invalid` with no
    /// image open, or when an adjustment fails.
    public func composite() throws -> PixelBuffer {
        guard let canvas else { throw RasterError.invalid("no image is open") }
        return try rendered(canvas.rect)
    }

    /// Rec. 709 luminance of the image as it enters Curves (the layers
    /// composited, then exposure and levels), counted on display (sRGB-encoded)
    /// values like the curve's axis, in 256 bins, with its clipping: the
    /// histogram Levels shows and the curve editor draws behind the curve.
    /// Empty with no image open, when every pixel is transparent, and when the
    /// task counting it is cancelled (it stops before the next row).
    /// Cost: it reads at most 256 evenly spaced rows, so about 256 x width
    /// pixels composited, adjusted and counted, whatever the image's height.
    /// A cancelled task stops between rows and gets `empty`.
    public func curvesHistogram() -> ToneHistogram {
        curvesHistogram { try composited($0) }
    }

    /// `curvesHistogram()` with each sampled row's composite kept in `composites` between counts
    /// (PhotoCompositeCache, the canvas routes' seam, here over a CPU dispatcher): a count after a tone edit
    /// composites nothing, and one after a layer change lays that layer and the ones above it on each row's kept
    /// base, never the stack. The same bits as the plain count (both routes are held to `composited(_:)`).
    public func curvesHistogram(composites: PhotoCompositeCache) -> ToneHistogram {
        let dispatcher = PhotoRenderRoute.cpu.dispatcher()
        // Counted as the reference path's rows and row layers, never as the canvas's renders.
        return PhotoRenderCount.asRows {
            curvesHistogram { row in
                PhotoRenderCount.row()
                let picture = try composited(row, on: dispatcher, cache: composites)
                defer { dispatcher.release(picture) }
                return try dispatcher.read(picture)  // render-contract: allow the CPU backend's own buffer, no GPU readback
            }
        }
    }

    /// The count over the sampled rows, each composited by `rows`; see `curvesHistogram()`.
    private func curvesHistogram(rows: (PixelRect) throws -> PixelBuffer) -> ToneHistogram {
        guard let canvas else { return .empty }
        var counts = [Int](repeating: 0, count: 256)
        var shadows = 0, highlights = 0
        for y in stride(from: 0, to: canvas.height, by: (canvas.height + 255) / 256) {
            guard !Task.isCancelled else { return .empty }
            let row = PixelRect(x: 0, y: y, width: canvas.width, height: 1)
            // Can't fail: the same pixels render on the canvas.
            guard let pixels = try? adjustments.appliedBeforeCurves(to: rows(row)),
                let histogram = try? Histogram(of: pixels, bins: counts.count, encoding: .sRGB)
            else { continue }
            counts = zip(counts, histogram.luminance).map(+)
            shadows += histogram.shadowClipped
            highlights += histogram.highlightClipped
        }
        return ToneHistogram(channels: [counts], shadowClipped: shadows, highlightClipped: highlights)
    }

    /// A value that changes exactly when `curvesHistogram()` can: with any
    /// change to the layers or their pixels, and with exposure or levels as
    /// they apply (a switched-off section counts as its defaults), and with the
    /// tone section, whose steps run before them. A Curves,
    /// Hue/Saturation or Blur edit leaves it as it was, so the inspector
    /// recounts only when it must, never during a curve drag.
    public var curvesHistogramKey: CurvesHistogramKey {
        let defaults = AdjustmentSettings(), on = adjustments
        let exposure = on.isEnabled(.exposure) ? on : defaults, levels = on.isEnabled(.levels) ? on : defaults
        return CurvesHistogramKey(
            content: contentRevision, toneSection: on.tone,
            tone: [exposure.exposure, levels.blackPoint, levels.whitePoint, levels.gamma, levels.outputBlack,
                   levels.outputWhite])
    }

    /// `rect` of the canvas, composited and adjusted.
    func rendered(_ rect: PixelRect) throws -> PixelBuffer {
        guard let canvas, let outer = rect.expanded(by: adjustments.readMargin).intersection(canvas.rect),
            let inner = rect.intersection(canvas.rect)
        else { throw RasterError.invalid("region \(rect) is outside the image") }
        let adjusted = try adjustments.applied(to: composited(outer))
        guard outer != inner else { return adjusted }
        return try adjusted.cropped(
            x: inner.x - outer.x, y: inner.y - outer.y, width: inner.width, height: inner.height)
    }

    /// The visible layers over transparency, bottom first, in `rect`, each
    /// through `PhotoLayerComposite` (only its tiles under `rect`, clipped
    /// there), so every pixel blends exactly as it would from the whole layer.
    func composited(_ rect: PixelRect) throws -> PixelBuffer {
        var result = try PixelBuffer(width: rect.width, height: rect.height)
        PhotoRenderCount.row()
        for layer in layers.reversed() where layer.isVisible && layer.opacity > 0 {
            PhotoRenderCount.rowLayers(1)
            let content = LayerContent(layer: layer, pixels: pixels[layer.id], mask: shownMask(of: layer))
            result = try PhotoLayerComposite.composite(
                content, onto: result, origin: (x: rect.x, y: rect.y),
                adjusting: services.adjustmentLayers, masking: services.masking)
        }
        return result
    }

    /// `layer`'s mask when it has one and it is enabled: what hides part of the layer on the canvas.
    func shownMask(of layer: PhotoLayer) -> TiledPixels? { layer.isMaskEnabled ? masks[layer.id] : nil }
}

/// See `PhotoWorkspace.curvesHistogramKey`.
public struct CurvesHistogramKey: Equatable, Sendable {
    let content: Int
    let toneSection: ToneSettings
    let tone: [Float]
}

public enum PhotoRenderer {
    /// `workspace` as display bytes. With a `previous` frame of the same size,
    /// only the tiles damaged since it are rendered again; the rest are kept.
    /// `onWhite` lays the picture on opaque white (JPEG export). Throws
    /// `RasterError` with no image open or when an adjustment fails.
    public static func render(
        _ workspace: PhotoWorkspace, after previous: PhotoFrame? = nil, onWhite: Bool = false
    ) async throws -> PhotoFrame {
        guard let canvas = workspace.canvas else { throw RasterError.invalid("no image is open") }
        let clock = ContinuousClock()
        let started = clock.now
        let reusable = previous.flatMap { $0.width == canvas.width && $0.height == canvas.height && !onWhite ? $0 : nil }
        let damage = reusable.map { workspace.damage(since: $0.revision) } ?? .all
        var bytes = reusable?.rgba8 ?? [UInt8](repeating: 0, count: canvas.width * canvas.height * 4)
        for (tile, tileBytes) in try await renderedTiles(workspace, tiles(of: canvas, in: damage), onWhite: onWhite) {
            for row in 0..<tile.height {
                let from = row * tile.width * 4
                let to = ((tile.y + row) * canvas.width + tile.x) * 4
                bytes.replaceSubrange(to..<(to + tile.width * 4), with: tileBytes[from..<(from + tile.width * 4)])
            }
        }
        let elapsed = clock.now - started
        let milliseconds = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        return PhotoFrame(
            width: canvas.width, height: canvas.height, rgba8: bytes, revision: workspace.revision,
            milliseconds: milliseconds)
    }

    /// `rects` of `workspace` as straight display bytes (premultiplied with
    /// `premultiplied`), each rendered in its own child task.
    static func renderedTiles(
        _ workspace: PhotoWorkspace, _ rects: [PixelRect], onWhite: Bool = false, premultiplied: Bool = false
    ) async throws -> [(PixelRect, [UInt8])] {
        try await withThrowingTaskGroup(of: (PixelRect, [UInt8]).self) { group in
            for tile in rects {
                group.addTask {
                    var picture = try workspace.rendered(tile)
                    if onWhite { picture = try picture.onWhite() }
                    var bytes = try picture.rgba8()
                    if premultiplied { Self.premultiply(&bytes) }
                    return (tile, bytes)
                }
            }
            var done: [(PixelRect, [UInt8])] = []
            done.reserveCapacity(rects.count)
            for try await tile in group { done.append(tile) }
            return done
        }
    }

    /// The canvas tiles (PixelBuffer.tileSize square, clipped to the canvas)
    /// that `damage` touches.
    public static func tiles(of canvas: CanvasSize, in damage: PhotoDamage) -> [PixelRect] {
        let size = PixelBuffer.tileSize
        let area: PixelRect
        switch damage {
        case .none: return []
        case .all: area = canvas.rect
        case .region(let region):
            guard let clipped = region.intersection(canvas.rect) else { return [] }
            area = clipped
        }
        var tiles: [PixelRect] = []
        for row in (area.y / size)...((area.maxY - 1) / size) {
            for column in (area.x / size)...((area.maxX - 1) / size) {
                let tile = PixelRect(x: column * size, y: row * size, width: size, height: size)
                if let clipped = tile.intersection(canvas.rect) { tiles.append(clipped) }
            }
        }
        return tiles
    }
}

extension PixelBuffer {
    /// This picture laid on opaque white, as JPEG needs.
    func onWhite() throws -> PixelBuffer {
        let white = try PixelBuffer(width: width, height: height, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
        return try CoreRaster.composite(self, onto: white, mode: .normal, opacity: 1)
    }
}
