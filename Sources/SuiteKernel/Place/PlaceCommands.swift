// PlaceCommands.swift (placed-images PL-1 specs with real ids, schemas and availability, runs throwing
// `PlaceRules.notBuilt`; PL-7 bodies): the five place commands every app registers with one line,
// `+ PlaceCommands.specs(<X>Workspace.self)`, and its `<X>Place+Kernel.swift` conformance.
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
                   availability: { $0.placedSelection == nil ? .unavailable(selectHelp) : .available }) { _, _ in try stub() },
            .typed("place.image", title: "Place Image", summary: "Places a PNG, JPEG or SVG fitted inside the canvas at a point, or with fill into the selected layer.",
                   kind: .edit, params: ImageParams.self,
                   schema: .object(["name": name, "base64": base64, "x": .optional(.number("Where the image's centre lands.")),
                                    "y": .optional(.number("Where the image's centre lands.")), "fill": .optional(.boolean)],
                                   required: ["name", "base64", "x", "y", "fill"]),
                   result: .object(["id": .string("The layer that shows the image.")], required: ["id"]), example: file,
                   availability: { $0.placeHelp.map(Availability.unavailable) ?? .available }) { _, _ in try stub() },
            .typed("place.replace", title: "Replace Image", summary: "Shows another file in the selected placed image's box.",
                   kind: .edit, params: ReplaceParams.self, schema: .object(["name": name, "base64": base64], required: ["name", "base64"]),
                   example: file, availability: { selected($0) }) { _, _ in try stub() },
            .typed("place.reset-size", title: "Reset Size", summary: "Gives the selected image's box its natural aspect, keeping its width and centre.",
                   kind: .edit, params: Empty.self, schema: ParamSchema.none, example: .object([:]),
                   availability: { selected($0, unless: { PlaceRules.resetBox($0, natural: $1) == $0.box }, naturalHelp) }) { _, _ in try stub() },
            .typed("place.focus", title: "Move Inside", summary: "Pans the picture inside its box to a unit focus; moves under one drag token are one undo step.",
                   kind: .edit, params: FocusParams.self, schema: .object(["x": unit, "y": unit, "drag": drag], required: ["x", "y", "drag"]),
                   example: .object(["x": .number(0.25), "y": .number(0.5)]),
                   availability: { selected($0, unless: { PlaceRules.drawnRect($0, natural: $1) == $0.box }, fitsHelp) }) { _, _ in try stub() },
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
    /// Every run until PL-7: refuses with `PlaceRules.notBuilt`.
    static func stub() throws -> JSONValue { throw PlaceRules.notBuilt }
}
