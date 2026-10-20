// PlaceCommands.swift (placed-images PL-1 specs with real ids, schemas and availability; PL-7 bodies): the five
// place commands every app registers with one line, `+ PlaceCommands.specs(<X>Workspace.self)`, and its
// `<X>Place+Kernel.swift` conformance. Each edit makes one target call, so it records one undo step; a focus
// drag passes its token so the target's `History` folds the drag into one.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A document pictures are placed into: an app's workspace conforms in its `<X>Place+Kernel.swift`.
public protocol PlacedImageTarget: Sendable {
    /// Why nothing can be placed now (no document, a locked parent); nil when it can.
    var placeHelp: String? { get }
    /// What a new image fits inside (the artboard, the comp, the image).
    var placeCanvas: Rect { get }
    /// The selected layer `fill: true` fills (a frame or rectangle, a solid); nil refuses the fill.
    var placeFillBox: Rect? { get }
    /// The formats this app takes: a vector-only app `[.svg]`, a raster-only app `[.png, .jpeg]`.
    var placeFormats: Set<PlacedFormat> { get }
    /// The selected layer's picture and its asset; nil when no placed image is selected.
    var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? { get }
    /// A raster file's pixel size from its header (no decode); an app that draws no pixels throws.
    func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size
    /// Adds a layer with a box showing `asset` in `image.box`, selects it, one undo step named `name`; returns its id.
    mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String
    /// Sets the selected layer's picture (a fill puts one into a layer without one); one `drag` token folds into one step.
    mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws
}

/// One gesture of the panel, the drop target or the rows; the app runs its `command` through its catalog.
public enum PlaceIntent: Hashable, Sendable {
    case place(name: String, data: Data, at: Point?), replace(name: String, data: Data), resetSize, focus(Point, drag: String)

    /// The gesture as the command it is: its id and params (a file as its name and its bytes in base64).
    public var command: (id: String, params: JSONValue) {
        let file = { (name: String, data: Data) -> [String: JSONValue] in ["name": .string(name), "base64": .string(data.base64EncodedString())] }
        switch self {
        case .place(let name, let data, let at):
            let point: [String: JSONValue] = at.map { ["x": .number($0.x), "y": .number($0.y)] } ?? [:]
            return ("place.image", .object(point.merging(file(name, data)) { old, _ in old }))
        case .replace(let name, let data): return ("place.replace", .object(file(name, data)))
        case .resetSize: return ("place.reset-size", .object([:]))
        case .focus(let p, let drag): return ("place.focus", .object(["x": .number(p.x), "y": .number(p.y), "drag": .string(drag)]))
        }
    }
}

public enum PlaceCommands {
    struct Empty: Codable, Sendable {}
    struct ImageParams: Codable, Sendable { var name, base64: String; var x, y: Double?; var fill: Bool? }
    struct ReplaceParams: Codable, Sendable { var name, base64: String }
    struct FocusParams: Codable, Sendable { var x, y: Double; var drag: String? }

    /// Why a command needs a placed image, why a fill can't run, and why reset and focus have nothing to do.
    static let selectHelp = "Select a placed image first.", fillBoxHelp = "Select a frame to fill."
    static let naturalHelp = "The image already has its own shape.", fitsHelp = "The image fits its box; there is nothing to move."

    static let name = ParamSchema.string("The file name, \"logo.svg\".", maxLength: 255)
    static let base64 = ParamSchema.string("The file's bytes, base64: PNG, JPEG or SVG, up to 32 MB.")
    static let unit = ParamSchema.number("0 to 1.", minimum: 0, maximum: 1), number = ParamSchema.number()
    static let drag = ParamSchema.optional(.string("A drag's token; edits under one token are one undo step.", maxLength: 64))
    static let rect = ParamSchema.object(["minX": number, "minY": number, "maxX": number, "maxY": number],
                                         required: ["minX", "minY", "maxX", "maxY"])
    static let read = ParamSchema.object(
        ["name": name, "format": .string("The file kind.", oneOf: PlacedFormat.allCases.map(\.rawValue)),
         "width": .number("The natural width: pixels, or SVG user units."), "height": .number("The natural height."),
         "box": rect, "focus": .object(["x": unit, "y": unit], required: ["x", "y"]), "drawn": rect],
        required: ["name", "format", "width", "height", "box", "focus", "drawn"])
    /// A 240 × 80 SVG: the example every app's fixture can place.
    static let logo = Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="240" height="80"/>"#.utf8).base64EncodedString()
    static let file: JSONValue = .object(["name": .string("logo.svg"), "base64": .string(logo)])

    /// The five place commands on `target`: `place.read` a query, the rest edits of one undo step each.
    public static func specs<T: PlacedImageTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("place.read", title: "Read Placed Image", summary: "Reads the selected placed image: its file, natural size, box, focus and drawn rect.",
                   kind: .query, params: Empty.self, schema: ParamSchema.none, result: read, example: .object([:]),
                   availability: { $0.placedSelection == nil ? .unavailable(selectHelp) : .available }) { t, _ in try reading(t) },
            .typed("place.image", title: "Place Image", summary: "Places a PNG, JPEG or SVG fitted inside the canvas at a point, or with fill into the selected layer.",
                   kind: .edit, params: ImageParams.self,
                   schema: .object(["name": name, "base64": base64, "x": .optional(.number("Where the image's centre lands.")),
                                    "y": .optional(.number("Where the image's centre lands.")), "fill": .optional(.boolean)],
                                   required: ["name", "base64", "x", "y", "fill"]),
                   result: .object(["id": .string("The layer that shows the image.")], required: ["id"]), example: file,
                   availability: { $0.placeHelp.map(Availability.unavailable) ?? .available }) { t, p in try place(&t, p) },
            .typed("place.replace", title: "Replace Image", summary: "Shows another file in the selected placed image's box.",
                   kind: .edit, params: ReplaceParams.self, schema: .object(["name": name, "base64": base64], required: ["name", "base64"]),
                   example: file, availability: { selected($0) }) { t, p in try replace(&t, p) },
            .typed("place.reset-size", title: "Reset Size", summary: "Gives the selected image's box its natural aspect, keeping its width and centre.",
                   kind: .edit, params: Empty.self, schema: ParamSchema.none, example: .object([:]),
                   availability: { selected($0, unless: { PlaceRules.resetBox($0, natural: $1) == $0.box }, naturalHelp) }) { t, _ in try resetSize(&t) },
            .typed("place.focus", title: "Move Inside", summary: "Pans the picture inside its box to a unit focus; moves under one drag token are one undo step.",
                   kind: .edit, params: FocusParams.self, schema: .object(["x": unit, "y": unit, "drag": drag], required: ["x", "y", "drag"]),
                   example: .object(["x": .number(0.25), "y": .number(0.5)]),
                   availability: { selected($0, unless: { PlaceRules.drawnRect($0, natural: $1) == $0.box }, fitsHelp) }) { t, p in try focus(&t, p) },
        ]
    }

    /// Available when the target can place and has a placed image selected; unavailable with `why` when `unless`
    /// holds for that image and its natural size.
    static func selected<T: PlacedImageTarget>(_ target: T, unless: (PlacedImage, Size) -> Bool = { _, _ in false },
                                               _ why: String = "") -> Availability {
        if let help = target.placeHelp { return .unavailable(help) }
        guard let selection = target.placedSelection else { return .unavailable(selectHelp) }
        return unless(selection.image, selection.asset.natural) ? .unavailable(why) : .available
    }

    /// `place.read`'s result: the file, its natural size, the box, the focus and where the picture draws.
    struct Reading: Encodable {
        var name: String; var format: PlacedFormat; var width, height: Double; var box: Rect; var focus: Point; var drawn: Rect
    }
    /// `place.image`'s result: the layer that shows the picture.
    struct Placed: Encodable { var id: String }

    /// The selected placed image as `place.read` reports it.
    static func reading<T: PlacedImageTarget>(_ target: T) throws -> Reading {
        let (_, image, asset) = try selection(target, "place.read")
        return Reading(name: asset.name, format: asset.format, width: asset.natural.width, height: asset.natural.height,
                       box: image.box, focus: image.focus, drawn: PlaceRules.drawnRect(image, natural: asset.natural))
    }
    /// The file fitted inside the canvas at `(x, y)` as a new layer, or with `fill` into the selected layer at its
    /// box (the cover crop does the rest); either is one step named Place Image.
    static func place<T: PlacedImageTarget>(_ target: inout T, _ p: ImageParams) throws -> Placed {
        if p.fill == true, target.placeFillBox == nil { throw CatalogError.unavailable(id: "place.image", why: fillBoxHelp) }
        let asset = try asset(target, "place.image", name: p.name, base64: p.base64)
        if p.fill == true, let box = target.placeFillBox {
            try target.setPlaced(PlacedImage(assetID: asset.id, box: box), asset: asset, name: "Place Image", drag: nil)
            guard let id = target.placedSelection?.id else {
                throw CatalogError.failed(id: "place.image", message: "The selected layer took no picture.")
            }
            return Placed(id: id)
        }
        let at = p.x.flatMap { x in p.y.map { Point(x: x, y: $0) } }
        let image = PlacedImage(assetID: asset.id, box: PlaceRules.fitted(natural: asset.natural, in: target.placeCanvas, at: at))
        return Placed(id: try target.insertPlaced(asset, image, name: "Place Image"))
    }
    /// The selected image's box showing another file, its focus back at the centre.
    static func replace<T: PlacedImageTarget>(_ target: inout T, _ p: ReplaceParams) throws -> Empty {
        let box = try selection(target, "place.replace").image.box
        let asset = try asset(target, "place.replace", name: p.name, base64: p.base64)
        try target.setPlaced(PlacedImage(assetID: asset.id, box: box), asset: asset, name: "Replace Image", drag: nil)
        return Empty()
    }
    /// The selected image's box at its natural aspect (same width and centre), its focus back at the centre.
    static func resetSize<T: PlacedImageTarget>(_ target: inout T) throws -> Empty {
        let (_, image, asset) = try selection(target, "place.reset-size")
        let reset = PlacedImage(assetID: image.assetID, box: PlaceRules.resetBox(image, natural: asset.natural))
        try target.setPlaced(reset, asset: nil, name: "Reset Size", drag: nil)
        return Empty()
    }
    /// The selected image's focus, clamped to the unit square, under the drag's token.
    static func focus<T: PlacedImageTarget>(_ target: inout T, _ p: FocusParams) throws -> Empty {
        var image = try selection(target, "place.focus").image
        image.focus = Point(x: min(max(p.x, 0), 1), y: min(max(p.y, 0), 1))
        try target.setPlaced(image, asset: nil, name: "Move Inside", drag: p.drag)
        return Empty()
    }

    /// The selected placed image, or `selectHelp` as the refusal of `id`.
    static func selection<T: PlacedImageTarget>(_ target: T, _ id: String) throws -> (id: String, image: PlacedImage, asset: PlacedAsset) {
        guard let selection = target.placedSelection else { throw CatalogError.unavailable(id: id, why: selectHelp) }
        return selection
    }
    /// The base64 file as an asset `target` takes: the size checked before the sniff, then the format against the
    /// target's set; its natural size from the SVG's flattening or the target's header read.
    static func asset<T: PlacedImageTarget>(_ target: T, _ id: String, name: String, base64: String) throws -> PlacedAsset {
        guard let data = Data(base64Encoded: base64) else { throw CatalogError.failed(id: id, message: "The file's bytes aren't base64.") }
        guard data.count <= PlaceRules.maxBytes else { throw CatalogError.unavailable(id: id, why: PlaceRules.sizeHelp) }
        guard let format = PlaceRules.format(of: data), target.placeFormats.contains(format) else {
            throw CatalogError.unavailable(id: id, why: PlaceRules.formatHelp)
        }
        let natural = format == .svg ? try PlaceRules.vector(data, name: name).size : try target.rasterSize(data, format: format)
        return PlacedAsset(id: PlaceRules.assetID(of: data), name: name, format: format, natural: natural, data: data)
    }
}
