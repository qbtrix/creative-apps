// StageRasterizer.swift: FrameRasterizing on CoreGraphics (docs/blueprints/flare/features/flare-export.md, FX-7;
// blueprint 7.6, LA-1). One StageDrawList becomes a PNG of `width × scale` by `height × scale` pixels: an RGBA8
// premultiplied sRGB bitmap context, flipped so the list's y-down scene space lands with its top row first, the CTM
// scaled by `scale`, the canvas filled with the list's background unless `transparent`, then every non-text item in
// paint order exactly as FlareStage draws it on screen: `StagePath.cgPath` with the item's matrix, the fill (solid or
// gradient, clipped to the path) and the stroke at `width × stretch` with its cap and join, both at the item's
// opacity. ImageIO encodes the CGImage as PNG. A zero or non-finite size, a context CoreGraphics won't make and a
// PNG it won't finalize each throw a RasterizerError; nothing here force-unwraps or crashes.
import CoreGraphics
import FlareCore
import FlareModel
import Foundation
import ImageIO

enum RasterizerError: Error, Equatable {
    /// The list's size times `scale` is zero, negative, not finite or wider than `StageRasterizer.maxSide`.
    case invalidSize
    /// CoreGraphics made no bitmap context or no image for this size.
    case contextUnavailable
    /// ImageIO could not write the PNG.
    case encodeFailed
}

struct StageRasterizer: FrameRasterizing {
    /// The longest side in pixels this draws; keeps `Int` conversion and the bitmap allocation bounded.
    static let maxSide = 16_384

    init() {}

    func png(_ list: StageDrawList, scale: Double, transparent: Bool) throws -> Data {
        let (width, height) = try Self.pixelSize(width: list.width, height: list.height, scale: scale)
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { throw RasterizerError.contextUnavailable }
        // CoreGraphics bitmaps are y-up; the list is y-down like the stage. Flip, then scale scene points to pixels.
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: CGFloat(scale), y: -CGFloat(scale))
        if !transparent {
            context.setFillColor(StagePath.cgColor(list.background))
            context.fill(CGRect(x: 0, y: 0, width: list.width, height: list.height))
        }
        for item in list.items where !item.isText { Self.draw(item, in: context) }
        guard let image = context.makeImage() else { throw RasterizerError.contextUnavailable }
        return try Self.encodePNG(image)
    }

    /// `width × scale` by `height × scale`, rounded to whole pixels; throws unless both are finite, at least 1 and
    /// at most `maxSide`.
    static func pixelSize(width: Double, height: Double, scale: Double) throws -> (width: Int, height: Int) {
        let w = width * scale, h = height * scale
        guard w.isFinite, h.isFinite, w >= 0.5, h >= 0.5, w <= Double(maxSide), h <= Double(maxSide) else {
            throw RasterizerError.invalidSize
        }
        return (Int(w.rounded()), Int(h.rounded()))
    }

    /// One item as FlareStage draws it: the path through its matrix, the fill, then the stroke, at its opacity.
    private static func draw(_ item: StageItem, in context: CGContext) {
        let path = StagePath.cgPath(item.path, transform: item.transform)
        guard !path.isEmpty else { return }
        // How far the matrix stretches a length, for stroke widths and gradient radii (the CTM adds `scale`).
        let stretch = abs(item.transform.determinant).squareRoot()
        context.saveGState()
        context.setAlpha(CGFloat(item.opacity))
        if let paint = item.fill { fill(path, with: paint, matrix: item.transform, stretch: stretch, in: context) }
        if let stroke = item.stroke, stroke.width > 0 {
            context.setStrokeColor(StagePath.cgColor(stroke.color))
            context.setLineWidth(CGFloat(stroke.width * stretch))
            context.setLineCap(cap(stroke.cap))
            context.setLineJoin(join(stroke.join))
            context.beginPath()
            context.addPath(path)
            context.strokePath()
        }
        context.restoreGState()
    }

    /// A solid fill paints the path; a gradient clips to it and paints the gradient, extended past both ends as
    /// the stage's shading is.
    private static func fill(_ path: CGPath, with fill: Fill, matrix: Matrix, stretch: Double, in context: CGContext) {
        func point(_ p: FlareCore.Point) -> CGPoint { let m = matrix.apply(p); return CGPoint(x: m.x, y: m.y) }
        let options: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        switch fill {
        case .solid(let color):
            context.setFillColor(StagePath.cgColor(color))
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

    /// The stops as an sRGB CGGradient; nil for no stops, which then paints nothing (as an empty SwiftUI gradient).
    private static func gradient(_ stops: [GradientStop]) -> CGGradient? {
        guard !stops.isEmpty, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let colors = stops.map { StagePath.cgColor($0.color) } as CFArray
        let locations = stops.map { CGFloat($0.offset) }
        return CGGradient(colorsSpace: space, colors: colors, locations: locations)
    }

    /// `image` as PNG bytes through ImageIO.
    private static func encodePNG(_ image: CGImage) throws -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else {
            throw RasterizerError.encodeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw RasterizerError.encodeFailed }
        return data as Data
    }

    private static func cap(_ cap: Stroke.Cap) -> CGLineCap {
        switch cap {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }

    private static func join(_ join: Stroke.Join) -> CGLineJoin {
        switch join {
        case .miter: .miter
        case .round: .round
        case .bevel: .bevel
        }
    }
}
