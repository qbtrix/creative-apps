// RetouchCommands.swift (fill-heal FH-1 specs, runs throwing NotBuilt; FH-6
// bodies): the four fill and heal commands a raster app adds with
// `+ RetouchCommands.specs(<X>Workspace.self)`: fill.bucket,
// retouch.spot-heal, retouch.heal and retouch.remove. Each is an edit of one
// undo step named for its tool, over `BucketRules` and `HealRules`.
import CoreRaster
import SuiteKernel

/// A document with a pixel layer to fill and heal: an app's workspace conforms in its `<X>Retouch+Kernel.swift`.
public protocol RetouchTarget: Sendable {
    /// Why nothing can be retouched now (no image, no pixel layer, a locked layer); nil when it can.
    var retouchHelp: String? { get }
    /// The selected pixel layer's pixels, document-sized.
    var targetPixels: PixelBuffer? { get }
    /// The merged picture, for All Layers.
    var mergedPixels: PixelBuffer? { get }
    /// The selection's coverage, document-sized; nil when nothing is selected.
    var selectionCoverage: Mask? { get }
    /// The colour the bucket paints, straight (not premultiplied).
    var paintColor: RGBA { get }
    /// The heal source as an offset from the stroke (Option-click); nil before one is sampled.
    var cloneOffset: (dx: Int, dy: Int)? { get }
    /// Replaces the selected layer's pixels as one undo step called `name`.
    mutating func replaceTarget(_ p: PixelBuffer, name: String) throws
}

/// The fill and heal commands.
public enum RetouchCommands {
    struct XY: Codable, Sendable { var x, y: Double }
    struct Color: Codable, Sendable { var r, g, b, a: Double }
    struct BucketParams: Codable, Sendable { var x, y: Double; var tolerance: Int?; var contiguous, allLayers: Bool?; var color: Color? }
    struct SpotParams: Codable, Sendable { var x, y, size: Double; var seed: Int? }
    struct HealParams: Codable, Sendable { var points: [XY]; var size: Double; var hardness: Double? }
    struct Done: Codable, Sendable {}
    struct RemoveParams: Codable, Sendable { var points: [XY]?; var size: Double?; var seed: Int? }

    /// Why heal can't run before a source is sampled.
    public static let sourceHelp = "Option-click a source first."
    /// Why remove has nothing to fill: no stroke and no selection.
    public static let removeHelp = "Paint over what to remove, or select it first."
    /// What a run throws until FH-6.
    public static let notBuilt = CatalogError.notBuilt(id: "retouch", feature: "fill-heal FH-6")

    static let unit = ParamSchema.number(minimum: 0, maximum: 1)
    static let points = ParamSchema.array(of: .object(["x": .number(), "y": .number()], required: ["x", "y"]), minItems: 1, maxItems: 100_000)
    static let size = ParamSchema.number("The brush's width in pixels, 1 to 500.", minimum: 1, maximum: 500)
    static let seed = ParamSchema.optional(.integer("Picks between equal sources, so a script repeats; 0 when left out.", minimum: 0))
    static let bucket = ParamSchema.object(
        ["x": .number("The seed pixel's x."), "y": .number("The seed pixel's y."),
         "tolerance": .optional(.integer("0 to 255; 32 when left out.", minimum: 0, maximum: 255)),
         "contiguous": .optional(.boolean),
         "allLayers": .optional(.boolean),
         "color": .optional(.object(["r": unit, "g": unit, "b": unit, "a": unit], required: ["r", "g", "b", "a"],
                                    description: "Straight colour, 0 to 1; the paint colour when left out."))],
        required: ["x", "y", "tolerance", "contiguous", "allLayers", "color"])
    static let spot = ParamSchema.object(["x": .number("The spot's centre x."), "y": .number("The spot's centre y."), "size": size, "seed": seed],
                                         required: ["x", "y", "size", "seed"])
    static let heal = ParamSchema.object(
        ["points": points, "size": size,
         "hardness": .optional(.number("Percent of the radius at full strength; 100 when left out.", minimum: 0, maximum: 100))],
        required: ["points", "size", "hardness"])
    static let remove = ParamSchema.object(
        ["points": .optional(points), "size": .optional(.number("The brush's width in pixels, 1 to 500; 20 when left out.", minimum: 1, maximum: 500)),
         "seed": seed],
        required: ["points", "size", "seed"])
    static let stroke: JSONValue = .array([(16.0, 16.0), (24, 20)].map { .object(["x": .number($0.0), "y": .number($0.1)]) })

    /// The four commands on `target`, in palette order; each an edit of one undo step.
    public static func specs<T: RetouchTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("fill.bucket", title: "Paint Bucket",
                   summary: "Fills the pixels like the seed's within a tolerance, touching it unless not contiguous, inside the selection.",
                   kind: .edit, params: BucketParams.self, schema: bucket,
                   example: .object(["x": .number(4), "y": .number(4), "tolerance": .number(32)]), availability: { ready($0) }) { _, _ -> Done in throw notBuilt },
            .typed("retouch.spot-heal", title: "Spot Heal", summary: "Rebuilds a round spot from the texture around it.",
                   kind: .edit, params: SpotParams.self, schema: spot,
                   example: .object(["x": .number(20), "y": .number(20), "size": .number(12)]), availability: { ready($0) }) { _, _ -> Done in throw notBuilt },
            .typed("retouch.heal", title: "Heal",
                   summary: "Paints texture from the sampled source along a stroke and blends its tone into the edge.",
                   kind: .edit, params: HealParams.self, schema: heal,
                   example: .object(["points": stroke, "size": .number(8)]),
                   availability: { ready($0, $0.cloneOffset != nil, else: sourceHelp) }) { _, _ -> Done in throw notBuilt },
            .typed("retouch.remove", title: "Remove",
                   summary: "Fills a stroke, or the selection when there is none, from its surroundings.",
                   kind: .edit, params: RemoveParams.self, schema: remove,
                   example: .object(["points": stroke, "size": .number(12)]), availability: { ready($0) }) { _, _ -> Done in throw notBuilt },
        ]
    }

    /// Available unless the target says why not, then unless `ok` is false.
    static func ready<T: RetouchTarget>(_ t: T, _ ok: Bool = true, else why: String = "") -> Availability {
        if let help = t.retouchHelp { return .unavailable(help) }
        return ok ? .available : .unavailable(why)
    }
}
