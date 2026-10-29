// PhotoDocumentRead+Kernel.swift: Photo as the kernel's `DocumentReading` document, so an agent can read the
// image (`document.read`: canvas size, layers top-first, the selected ids) and look at it (`view.snapshot`: one
// render of the canvas or a region, downscaled and encoded through the window's codec), plus `paint.stroke`, a
// brush stroke along given points on the selected pixel layer as one undo step, "Brush Stroke". The stroke
// runs Photo's own brush engine (`drag` / `endDrag` with the Brush tool), then puts the tool and the brush
// options back, so the person's brush is as they left it. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel

extension PhotoWorkspace: DocumentReading {
    static let noImageHelp = "Open or make an image first."

    /// The image as an agent reads it; nil with no image open.
    public var documentOutline: DocumentOutline? {
        guard let canvas else { return nil }
        let rows = layers.map { layer in
            DocumentOutline.Layer(id: layer.id, name: layer.name, kind: Self.kindName(layer.kind),
                                  box: bounds(of: layer).map(Self.box), hidden: !layer.isVisible, opacity: layer.opacity)
        }
        return DocumentOutline(width: Double(canvas.width), height: Double(canvas.height), layers: rows, selected: selectedLayerIDs)
    }

    static func kindName(_ kind: PhotoLayerKind) -> String {
        switch kind {
        case .pixels: "pixels"
        case .adjustment: "adjustment"
        case .text: "text"
        }
    }

    /// One render of `region` (the canvas when nil) as the canvas shows it, scaled to `maxSide`, as PNG.
    public func snapshotPNG(maxSide: Int, region: Rect?) throws -> (png: Data, width: Int, height: Int) {
        guard let canvas else { throw CatalogError.unavailable(id: "view.snapshot", why: Self.noImageHelp) }
        var rect = canvas.rect
        if let region {
            let x = Int(region.minX.rounded(.down)), y = Int(region.minY.rounded(.down))
            let asked = PixelRect(x: x, y: y, width: max(Int(region.maxX.rounded(.up)) - x, 0), height: max(Int(region.maxY.rounded(.up)) - y, 0))
            guard let inside = asked.intersection(canvas.rect), !inside.isEmpty else {
                throw CatalogError.failed(id: "view.snapshot", message: "The region misses the canvas.")
            }
            rect = inside
        }
        var picture = try rendered(rect)
        let size = DocumentReadCommands.fitted(width: rect.width, height: rect.height, maxSide: maxSide)
        if size.width != rect.width || size.height != rect.height {
            picture = try picture.resized(width: size.width, height: size.height, filter: .bilinear)
        }
        let image = DecodedImage(rgba8: try picture.rgba8(), width: picture.width, height: picture.height)
        return (try fileFlow.codec.encode(image, as: .png, quality: 1), picture.width, picture.height)
    }
}

extension PhotoWorkspace {
    struct StrokePoint: Codable, Sendable { var x, y: Double }
    struct StrokeColor: Codable, Sendable { var r, g, b, a: Double }
    struct PaintStrokeParams: Codable, Sendable {
        var points: [StrokePoint]; var size, hardness: Double; var color: StrokeColor; var opacity: Double
    }
    static let paintHelp = "Select an image layer to paint on."
    static let unit = ParamSchema.number(minimum: 0, maximum: 1)
    static let paintSchema = ParamSchema.object(
        ["points": .array(of: .object(["x": .number(), "y": .number()], required: ["x", "y"]), minItems: 1, maxItems: 10_000),
         "size": .number("Brush diameter in pixels.", minimum: ToolOptions.sizeRange.lowerBound, maximum: ToolOptions.sizeRange.upperBound),
         "hardness": .number("0 soft to 1 hard.", minimum: 0, maximum: 1),
         "color": .object(["r": unit, "g": unit, "b": unit, "a": unit], required: ["r", "g", "b", "a"], description: "sRGB, 0 to 1."),
         "opacity": .number("0 to 1; times the colour's alpha.", minimum: 0, maximum: 1)],
        required: ["points", "size", "hardness", "color", "opacity"])
    static let paintExample = JSONValue.object([
        "points": .array([.object(["x": .number(2), "y": .number(2)]), .object(["x": .number(10), "y": .number(8)])]),
        "size": .number(4), "hardness": .number(1), "opacity": .number(1),
        "color": .object(["r": .number(1), "g": .number(0), "b": .number(0), "a": .number(1)])])

    /// `document.read`, `view.snapshot` and `paint.stroke`.
    static var agentCommands: [CommandSpec<PhotoWorkspace>] {
        DocumentReadCommands.specs(PhotoWorkspace.self) + [
            .typed("paint.stroke", title: "Brush Stroke", summary: "Paints one brush stroke through the points on the selected image layer, with a size, hardness, colour and opacity, as one undo step.",
                   kind: .edit, params: PaintStrokeParams.self, schema: paintSchema, example: paintExample,
                   availability: { $0.paintStrokeHelp.map(Availability.unavailable) ?? .available }) { w, p in
                try w.paintStroke(p)
                return JSONValue.object([:])
            },
        ]
    }

    /// Why `paint.stroke` can't run now: no image, a drag in progress, or no image layer selected.
    var paintStrokeHelp: String? {
        guard canvas != nil else { return Self.noImageHelp }
        guard stroke == nil else { return "Finish the drag on the canvas first." }
        guard let layer = selectedLayer, case .pixels = layer.kind else { return Self.paintHelp }
        return nil
    }

    /// Paints `p` with the Brush tool's engine as one step named "Brush Stroke", then restores the tool and the brush.
    mutating func paintStroke(_ p: PaintStrokeParams) throws {
        if let why = paintStrokeHelp { throw CatalogError.unavailable(id: "paint.stroke", why: why) }
        let (kept, options) = (tool, brushOptions)
        selectTool(.brush)
        let byte = { (v: Double) in UInt8((min(max(v, 0), 1) * 255).rounded()) }
        setToolOption(.size(p.size))
        setToolOption(.hardness(percent: p.hardness * 100))
        setToolOption(.opacity(percent: max(p.opacity * p.color.a * 100, ToolOptions.opacityRange.lowerBound)))
        setToolOption(.color(red: byte(p.color.r), green: byte(p.color.g), blue: byte(p.color.b)))
        let points = p.points.map { Mask.Point(x: $0.x, y: $0.y) }
        var last = points.first ?? Mask.Point(x: 0, y: 0)
        for point in points.count == 1 ? points : Array(points.dropFirst()) {
            drag(from: last, to: point)
            last = point
        }
        stroke?.stepName = "Brush Stroke"
        endDrag()
        setToolOption(.size(options.size))
        setToolOption(.hardness(percent: options.hardnessPercent))
        setToolOption(.opacity(percent: options.opacityPercent))
        setToolOption(.color(red: options.red, green: options.green, blue: options.blue))
        selectTool(kept)
    }
}
