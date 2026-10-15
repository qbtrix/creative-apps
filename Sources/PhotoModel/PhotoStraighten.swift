// PhotoStraighten.swift: Image > Straighten, turning the whole image clockwise
// by a small angle (-45 to 45 degrees) to level a tilted horizon. Every layer
// turns with CoreRaster's rotated(degrees:filter:) (lanczos3) about the canvas
// center, so layers keep their places relative to each other. With Crop to Fit
// the canvas becomes CoreRaster's straightenCrop rectangle (no transparent
// corners); without it the canvas grows to the turned bounds. Like Rotate and
// Image Size, it keeps every layer pixel, including those now off the canvas.
// One undo step keeping the whole stack that tells every layer's extras
// (layerGeometryChanged, PV-5's masks) once; it drops the selection and a pending
// crop. Angle 0, a non-finite angle or one out of range changes nothing. The
// turn is slow on a big photo (seconds with lanczos3), so `straightened` works
// it out without changing anything, off the main actor, and
// `commitStraighten` applies it unless the image changed meanwhile.
// `straightenFrame` is the same arithmetic without the pixels, for the sheet's
// preview and its "new size" line.
// Invariant: `turnedSize` computes exactly what rotated(degrees:filter:) gives
// for a canvas-sized buffer (PhotoStraightenTests checks it). libm comes from
// Glibc/Musl/Darwin as in CoreRaster, since FoundationEssentials on Linux does
// not promise cos and sin. Linux-safe.
#if canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif
import CoreRaster

/// What straightening the canvas by an angle makes, without turning pixels.
public struct StraightenFrame: Sendable, Hashable {
    /// The canvas before the turn.
    public let canvas: CanvasSize
    /// The size that holds the whole turned canvas.
    public let turned: CanvasSize
    /// The part of the turned canvas that becomes the new canvas, in its pixels.
    public let crop: PixelRect
    /// The new canvas size.
    public var size: CanvasSize { CanvasSize(width: crop.width, height: crop.height) }
    /// `crop`'s top-left corner over the canvas before the turn (the two share
    /// a center), where the preview shades it; can be a half pixel.
    public var cropOrigin: (x: Double, y: Double) {
        (Double(2 * crop.x - turned.width + canvas.width) / 2, Double(2 * crop.y - turned.height + canvas.height) / 2)
    }
}

/// A straighten worked out by `PhotoWorkspace.straightened`, waiting for
/// `commitStraighten`.
public struct StraightenResult: Sendable {
    /// The workspace's revision and layer list it was worked out from.
    let revision: Int
    let layers: [PhotoLayer]
    /// The angle and the turned canvas's crop, for `layerGeometryChanged`.
    let degrees: Double
    let crop: PixelRect
    /// The turned image.
    let stack: PhotoStack
}

extension PhotoWorkspace {
    /// The angles Straighten accepts, in degrees clockwise.
    public static let straightenRange: ClosedRange<Double> = -45...45

    /// What `straighten(degrees:cropToFit:)` would make of the open canvas; nil
    /// with no image, or an angle outside `straightenRange` (NaN included).
    public func straightenFrame(degrees: Double, cropToFit: Bool) -> StraightenFrame? {
        guard let canvas, Self.straightenRange.contains(degrees),
            let turned = Self.turnedSize(canvas, degrees)
        else { return nil }
        guard cropToFit else { return StraightenFrame(canvas: canvas, turned: turned, crop: turned.rect) }
        guard let crop = try? PixelBuffer.straightenCrop(width: canvas.width, height: canvas.height, degrees: degrees)
        else { return nil }
        return StraightenFrame(
            canvas: canvas, turned: turned, crop: PixelRect(x: crop.x, y: crop.y, width: crop.width, height: crop.height))
    }

    /// Turns the whole image clockwise by `degrees` at once: `straightened`,
    /// then `commitStraighten`. Ignores no image, 0, or an angle
    /// `straightenFrame` rejects. Throws `RasterError` when CoreRaster can't
    /// turn a layer (a turned size over its pixel limit); the workspace is
    /// then unchanged.
    public mutating func straighten(degrees: Double, cropToFit: Bool) throws {
        guard let result = try straightened(degrees: degrees, cropToFit: cropToFit) else { return }
        commitStraighten(result)
    }

    /// The image turned by `degrees`, worked out without changing anything,
    /// so it can run off the main actor; nil where `straighten` does nothing.
    public func straightened(degrees: Double, cropToFit: Bool) throws -> StraightenResult? {
        guard degrees != 0, let canvas, let frame = straightenFrame(degrees: degrees, cropToFit: cropToFit) else { return nil }
        let radians = degrees * Double.pi / 180
        let (c, s) = (cos(radians), sin(radians))
        var turned = stackState
        for (at, layer) in layers.enumerated() {
            guard let buffer = try pixels[layer.id]?.flattened() else { continue }
            let rotated = try buffer.rotated(degrees: degrees, filter: .lanczos3)
            // The layer's center, from the canvas center, turned the way rotated turns pixels.
            let u = Double(2 * layer.offsetX + buffer.width - canvas.width) / 2
            let v = Double(2 * layer.offsetY + buffer.height - canvas.height) / 2
            let x = Double(frame.turned.width - rotated.width) / 2 + u * c - v * s
            let y = Double(frame.turned.height - rotated.height) / 2 + u * s + v * c
            // ponytail: rounding can shift a layer smaller than the canvas by up to half a pixel; pad layers to the canvas if that ever shows.
            turned.layers[at].offsetX = Int(x.rounded()) - frame.crop.x
            turned.layers[at].offsetY = Int(y.rounded()) - frame.crop.y
            turned.pixels[layer.id] = TiledPixels(rotated)
        }
        turned.canvas = frame.size
        turned.selection = nil
        return StraightenResult(revision: revision, layers: layers, degrees: degrees, crop: frame.crop, stack: turned)
    }

    /// Makes `result` the image, as one "Straighten" undo step, and returns
    /// true. A result worked out before another change (the revision or the
    /// layer list moved since) or arriving mid-drag is stale: it returns
    /// false and changes nothing.
    @discardableResult
    public mutating func commitStraighten(_ result: StraightenResult) -> Bool {
        guard stroke == nil, result.revision == revision, result.layers == layers else { return false }
        var stack = result.stack
        stack.selectedLayerID = selectedLayerID
        record(.stack(stackState), named: "Straighten")
        restore(stack)
        for layer in layers { layerGeometryChanged(layer.id, .straightened(degrees: result.degrees, crop: result.crop)) }
        touch(.all)
        return true
    }

    /// The size rotated(degrees:filter:) gives a `canvas`-sized buffer: its
    /// turned bounds, rounded up, written as CoreRaster writes it; nil when
    /// CoreRaster would reject that size.
    static func turnedSize(_ canvas: CanvasSize, _ degrees: Double) -> CanvasSize? {
        let radians = degrees * Double.pi / 180
        let (w, h, c, s) = (Double(canvas.width), Double(canvas.height), abs(cos(radians)), abs(sin(radians)))
        let size = CanvasSize(width: Int((w * c + h * s).rounded(.up)), height: Int((w * s + h * c).rounded(.up)))
        guard (try? PixelBuffer.validatedSize(width: size.width, height: size.height)) != nil else { return nil }
        return size
    }
}
