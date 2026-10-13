// PhotoRender.swift: how Photo turns its layers into the picture. A region of
// the canvas renders by compositing the visible layers bottom-up at their
// offsets with their blend mode and opacity (CoreRaster's composite), then
// running the enabled adjustments in order: exposure, levels, hue/saturation,
// blur. The blur reads a margin of 3 sigma around the region, so a region
// renders exactly as the same pixels of the whole image would. `composite()`
// is the whole image at full size (export, tests); PhotoRenderer turns a
// workspace into display bytes (sRGB, straight alpha) tile by tile, in
// parallel, redrawing only the tiles that changed since the frame before
// (PhotoWorkspace.damage(since:)) and timing itself for the status line.
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

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

    /// The enabled adjustments applied to `buffer`, in order.
    func applied(to buffer: PixelBuffer) throws -> PixelBuffer {
        var result = buffer
        if isEnabled(.exposure) { result = try result.exposure(stops: exposure) }
        if isEnabled(.levels) {
            result = try result.levels(inBlack: blackPoint, inWhite: whitePoint, gamma: gamma, outBlack: 0, outWhite: 1)
        }
        if isEnabled(.hueSaturation) {
            result = try result.hueSaturation(hue: hue, saturation: saturation, lightness: lightness)
        }
        if blurMargin > 0 { result = try result.gaussianBlur(sigma: blurSigma) }
        return result
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

    /// `rect` of the canvas, composited and adjusted.
    func rendered(_ rect: PixelRect) throws -> PixelBuffer {
        guard let canvas, let outer = rect.expanded(by: adjustments.blurMargin).intersection(canvas.rect),
            let inner = rect.intersection(canvas.rect)
        else { throw RasterError.invalid("region \(rect) is outside the image") }
        let adjusted = try adjustments.applied(to: composited(outer))
        guard outer != inner else { return adjusted }
        return try adjusted.cropped(
            x: inner.x - outer.x, y: inner.y - outer.y, width: inner.width, height: inner.height)
    }

    /// The visible layers over transparency, bottom first, in `rect`. Each
    /// layer tile under `rect` composites in place (composite clips it), so
    /// every pixel blends exactly as it would from the whole layer.
    func composited(_ rect: PixelRect) throws -> PixelBuffer {
        var result = try PixelBuffer(width: rect.width, height: rect.height)
        for layer in layers.reversed() where layer.isVisible && layer.opacity > 0 {
            guard let tiled = pixels[layer.id] else { continue }
            for i in tiled.tileIndices(in: rect.offsetBy(-layer.offsetX, -layer.offsetY))
            where tiled.tiles.indices.contains(i) {
                let tile = tiled.tileRect(i).offsetBy(layer.offsetX - rect.x, layer.offsetY - rect.y)
                result = try CoreRaster.composite(
                    tiled.tiles[i], onto: result, x: tile.x, y: tile.y, mode: layer.blendMode,
                    opacity: Float(layer.opacity))
            }
        }
        return result
    }
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
        let tiles = tiles(of: canvas, in: damage)
        try await withThrowingTaskGroup(of: (PixelRect, [UInt8]).self) { group in
            for tile in tiles {
                group.addTask {
                    var picture = try workspace.rendered(tile)
                    if onWhite { picture = try picture.onWhite() }
                    return (tile, try picture.rgba8())
                }
            }
            for try await (tile, tileBytes) in group {
                for row in 0..<tile.height {
                    let from = row * tile.width * 4
                    let to = ((tile.y + row) * canvas.width + tile.x) * 4
                    bytes.replaceSubrange(to..<(to + tile.width * 4), with: tileBytes[from..<(from + tile.width * 4)])
                }
            }
        }
        let elapsed = clock.now - started
        let milliseconds = Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        return PhotoFrame(
            width: canvas.width, height: canvas.height, rgba8: bytes, revision: workspace.revision,
            milliseconds: milliseconds)
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
