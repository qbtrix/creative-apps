// VectorRasterizer.swift: the suite's one vector draw-list rasterizer (#5079). A VectorDrawList (points, y down,
// the kernel's path, fill, stroke and matrix, plus placed text) becomes a CGImage `width × scale` by
// `height × scale` pixels: an 8-bit sRGB bitmap with premultiplied alpha, flipped so its top row comes first, the CTM
// scaled by `scale`, filled with the background unless it is nil (clear), then every item in paint order. An item
// clips to its `clip` (list space), draws at its opacity, fills its path through its matrix (solid, or a gradient
// clipped to the path and extended past both ends), then strokes `strokePath` (the caller's trimmed, dashed outline)
// or the path at `width ×` the matrix's stretch with its cap and join. Text goes through GlyphRasterizer's drawing,
// under the item's matrix. `png` encodes the image through SuiteImageIO. Curves stay curves: each path element is
// one CG element, and one with a non-finite point after the matrix is skipped. A bad size, a context Core Graphics
// won't make and a PNG that won't encode each throw a VectorRasterError; nothing here force-unwraps. macOS only.
#if canImport(AppKit)
import CoreGraphics
import FlareCore
import Foundation
import SuiteKernel
import SuiteModel

/// What one picture draws, in points, y down; items in paint order, bottom first.
public struct VectorDrawList: Sendable, Equatable {
    public var width: Double, height: Double
    /// The canvas colour; nil leaves it clear.
    public var background: FillColor?
    public var items: [VectorDrawItem]
    public init(width: Double, height: Double, background: FillColor?, items: [VectorDrawItem]) {
        self.width = width; self.height = height; self.background = background; self.items = items
    }
}

/// One mark: a path filled and stroked, or a placed text span, through `transform`, at `opacity`, inside `clip`.
public struct VectorDrawItem: Sendable, Equatable {
    public var path: VectorPath
    public var fill: Fill?, stroke: VectorStroke?
    /// What the stroke paints (the path trimmed and dashed); nil strokes `path`.
    public var strokePath: VectorPath?
    public var text: PlacedSpan?
    public var transform: Matrix
    public var opacity: Double
    /// A clip in list space; nil draws unclipped.
    public var clip: VectorPath?
    public init(path: VectorPath = VectorPath(), fill: Fill? = nil, stroke: VectorStroke? = nil,
                strokePath: VectorPath? = nil, text: PlacedSpan? = nil, transform: Matrix = .identity,
                opacity: Double = 1, clip: VectorPath? = nil) {
        self.path = path; self.fill = fill; self.stroke = stroke; self.strokePath = strokePath; self.text = text
        self.transform = transform; self.opacity = opacity; self.clip = clip
    }
}

public enum VectorRasterError: Error, Equatable {
    /// The list's size times the scale is under a pixel, not finite, or over `VectorRasterizer.maxSide`.
    case invalidSize
    /// Core Graphics made no bitmap context or image.
    case contextUnavailable
    /// The PNG couldn't be encoded.
    case encodeFailed
}

public struct VectorRasterizer: Sendable {
    /// The longest side in pixels; keeps `Int` conversion and the bitmap allocation bounded.
    public static let maxSide = 16_384

    public init() {}

    /// `list` drawn at `scale` pixels per point into an 8-bit sRGB premultiplied image.
    public func image(_ list: VectorDrawList, scale: Double) throws(VectorRasterError) -> CGImage {
        let (width, height) = try Self.pixelSize(width: list.width, height: list.height, scale: scale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw .contextUnavailable }
        context.setShouldAntialias(true)
        context.setAllowsFontSmoothing(false)
        context.setShouldSmoothFonts(false)
        // CoreGraphics bitmaps are y-up; the list is y-down. Flip, then scale points to pixels.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        if let background = list.background {
            context.setFillColor(Self.cgColor(background))
            context.fill(CGRect(x: 0, y: 0, width: list.width, height: list.height))
        }
        for item in list.items { Self.draw(item, in: context) }
        guard let image = context.makeImage() else { throw .contextUnavailable }
        return image
    }

    /// `list` at `scale` as PNG bytes.
    public func png(_ list: VectorDrawList, scale: Double) throws(VectorRasterError) -> Data {
        let image = try image(list, scale: scale)
        do { return try SuiteImageIO.encode(image, as: .png, quality: nil) } catch { throw .encodeFailed }
    }

    /// `width × scale` by `height × scale`, rounded to whole pixels; throws unless both are finite, at least 1 and
    /// at most `maxSide`.
    public static func pixelSize(width: Double, height: Double, scale: Double) throws(VectorRasterError)
        -> (width: Int, height: Int) {
        let w = width * scale, h = height * scale
        guard w.isFinite, h.isFinite, w >= 0.5, h >= 0.5, w <= Double(maxSide), h <= Double(maxSide) else {
            throw .invalidSize
        }
        return (Int(w.rounded()), Int(h.rounded()))
    }

    private static func draw(_ item: VectorDrawItem, in context: CGContext) {
        context.saveGState()
        defer { context.restoreGState() }
        if let clip = item.clip {
            context.beginPath()
            context.addPath(cgPath(clip, transform: .identity))
            context.clip()
        }
        context.setAlpha(CGFloat(item.opacity))
        if let text = item.text, let placed = try? TextRules.validated(text) {
            // GlyphRasterizer draws y-up from a frame `height` tall; with height 0 and y flipped back it lands at
            // the span's own origins in the item's space.
            context.concatenate(cgAffine(item.transform))
            context.scaleBy(x: 1, y: -1)
            GlyphRasterizer.draw(placed, in: context, height: 0)
            return
        }
        let path = cgPath(item.path, transform: item.transform)
        guard !path.isEmpty else { return }
        // How far the matrix stretches a length, for stroke widths and gradient radii (the CTM adds `scale`).
        let stretch = abs(item.transform.determinant).squareRoot()
        if let paint = item.fill { fill(path, with: paint, matrix: item.transform, stretch: stretch, in: context) }
        if let stroke = item.stroke, stroke.width > 0 {
            context.setStrokeColor(cgColor(stroke.color))
            context.setLineWidth(CGFloat(stroke.width * stretch))
            context.setLineCap(cap(stroke.cap))
            context.setLineJoin(join(stroke.join))
            context.beginPath()
            context.addPath(item.strokePath.map { cgPath($0, transform: item.transform) } ?? path)
            context.strokePath()
        }
    }

    /// A solid fill paints the path; a gradient clips to it and paints the gradient, extended past both ends.
    private static func fill(_ path: CGPath, with fill: Fill, matrix: Matrix, stretch: Double, in context: CGContext) {
        func point(_ p: Point) -> CGPoint { let m = matrix.apply(p); return CGPoint(x: m.x, y: m.y) }
        let options: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        switch fill {
        case .solid(let color):
            context.setFillColor(cgColor(color))
            context.beginPath()
            context.addPath(path)
            context.fillPath()
        case .linear(let stops, let start, let end):
            guard let shading = gradient(stops) else { return }
            context.saveGState()
            context.beginPath()
            context.addPath(path)
            context.clip()
            context.drawLinearGradient(shading, start: point(start), end: point(end), options: options)
            context.restoreGState()
        case .radial(let stops, let center, let radius):
            guard let shading = gradient(stops) else { return }
            context.saveGState()
            context.beginPath()
            context.addPath(path)
            context.clip()
            let c = point(center)
            context.drawRadialGradient(
                shading, startCenter: c, startRadius: 0, endCenter: c, endRadius: CGFloat(radius * stretch),
                options: options)
            context.restoreGState()
        }
    }

    /// The stops as an sRGB CGGradient; nil for no stops, which then paints nothing.
    private static func gradient(_ stops: [GradientStop]) -> CGGradient? {
        guard !stops.isEmpty, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let colors = stops.map { cgColor($0.color) } as CFArray
        return CGGradient(colorsSpace: space, colors: colors, locations: stops.map { CGFloat($0.offset) })
    }

    /// `path` with every point mapped by `transform`, one CG element per path element. An element with a
    /// non-finite point after the transform is skipped; a drawing element with no current point starts its subpath
    /// at its end point.
    public static func cgPath(_ path: VectorPath, transform: Matrix) -> CGPath {
        let result = CGMutablePath()
        var hasCurrentPoint = false
        func point(_ p: Point) -> CGPoint? {
            let mapped = transform.apply(p)
            guard mapped.x.isFinite, mapped.y.isFinite else { return nil }
            return CGPoint(x: mapped.x, y: mapped.y)
        }
        func segment(to end: CGPoint, _ draw: () -> Void) {
            if hasCurrentPoint { draw() } else { result.move(to: end); hasCurrentPoint = true }
        }
        for element in path.elements {
            switch element {
            case .move(let to):
                guard let to = point(to) else { continue }
                result.move(to: to)
                hasCurrentPoint = true
            case .line(let to):
                guard let to = point(to) else { continue }
                segment(to: to) { result.addLine(to: to) }
            case .quad(let control, let to):
                guard let control = point(control), let to = point(to) else { continue }
                segment(to: to) { result.addQuadCurve(to: to, control: control) }
            case .cubic(let control1, let control2, let to):
                guard let control1 = point(control1), let control2 = point(control2), let to = point(to) else {
                    continue
                }
                segment(to: to) { result.addCurve(to: to, control1: control1, control2: control2) }
            case .close:
                guard hasCurrentPoint else { continue }
                result.closeSubpath()
            }
        }
        return result
    }

    /// `color`'s straight-alpha sRGB channels as a CGColor.
    public static func cgColor(_ color: FillColor) -> CGColor {
        CGColor(srgbRed: color.r, green: color.g, blue: color.b, alpha: color.a)
    }

    private static func cgAffine(_ m: Matrix) -> CGAffineTransform {
        CGAffineTransform(a: m.a, b: m.b, c: m.c, d: m.d, tx: m.tx, ty: m.ty)
    }

    private static func cap(_ cap: StrokeCap) -> CGLineCap {
        switch cap {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }

    private static func join(_ join: StrokeJoin) -> CGLineJoin {
        switch join {
        case .miter: .miter
        case .round: .round
        case .bevel: .bevel
        }
    }
}
#endif
