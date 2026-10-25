// AdjustCommands.swift (adjust-everywhere AJ-1 specs with real ids, schemas and
// availability, runs throwing NotBuilt; AJ-6 bodies): the commands an app adds
// with `+ AdjustCommands.specs(<X>Workspace.self)`. adjust.black-and-white and
// adjust.invert set the kinds, filter.<id> runs one filter on the selected
// layer inside the selection, and look.apply sets tone, adjust and kinds; each
// is one undo step named its title. look.list, look.save and look.delete read
// and write the suite's preset store, not the document. Linux-safe.
import SuiteKernel
import SuiteModel

/// A picture whose adjustments, filters and looks can be set: an app's workspace conforms in its `<X>Adjust+Kernel.swift`.
public protocol AdjustTarget: Sendable {
    /// Why nothing can be adjusted now (no picture open); nil when it can.
    var adjustHelp: String? { get }
    /// Why filters can't run (no pixel layer selected; Library: "Filters are in Photo."); nil when they can.
    var filterHelp: String? { get }
    /// The target's values as an unsaved look.
    var currentLook: LookPreset { get }
    var kinds: [ImagingKind] { get }
    /// Replaces the kinds as one undo step called `name`.
    mutating func setKinds(_ k: [ImagingKind], name: String) throws
    /// Runs `f` on the selected layer, inside the selection, as one undo step called `name`.
    mutating func applyFilter(_ f: ImagingFilter, name: String) throws
    /// Sets tone, adjust and kinds from `l` as one undo step called `name`.
    mutating func applyLook(_ l: LookPreset, name: String) throws
    /// The suite's saved looks.
    var looks: any PresetStoring { get }
}

/// The adjust, filter and look commands.
public enum AdjustCommands {
    struct BWParams: Codable, Sendable { var weights: GrayWeights? }
    struct NoParams: Codable, Sendable {}
    struct BlurParams: Codable, Sendable { var radius: Double }
    struct MotionParams: Codable, Sendable { var degrees, distance: Double }
    struct SharpenParams: Codable, Sendable { var amount, radius, threshold: Double }
    struct ReduceParams: Codable, Sendable { var strength, detail: Double }
    struct NoiseParams: Codable, Sendable { var amount: Double; var monochrome: Bool?; var seed: Int? }
    struct LookID: Codable, Sendable { var id: String }
    struct LookName: Codable, Sendable { var name: String }
    struct LookRow: Codable, Sendable { var id, name: String; var builtIn: Bool }
    struct Done: Codable, Sendable {}

    /// What a run throws until AJ-6.
    public static let notBuilt = CatalogError.notBuilt(id: "adjust", feature: "adjust-everywhere AJ-6")

    static func range(_ what: String, _ r: ClosedRange<Double>) -> ParamSchema {
        .number(what, minimum: r.lowerBound, maximum: r.upperBound)
    }
    static let weight = range("Percent, -200 to 300.", GrayWeights.range)
    static let weights = ParamSchema.object(
        ["red": weight, "yellow": weight, "green": weight, "cyan": weight, "blue": weight, "magenta": weight],
        required: ["red", "yellow", "green", "cyan", "blue", "magenta"], description: "The six hue weights.")
    static let bw = ParamSchema.object(["weights": .optional(weights)], required: ["weights"])
    static let id = ParamSchema.object(["id": .string("The look's id.")], required: ["id"])
    static let name = ParamSchema.object(["name": .string("The new look's name, unique ignoring case.", maxLength: 64)], required: ["name"])
    static let row = ParamSchema.object(["id": .string(), "name": .string(), "builtIn": .boolean], required: ["id", "name", "builtIn"])

    /// The two kinds, five filters and four look commands on `target`.
    public static func specs<T: AdjustTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        kindSpecs(target) + filterSpecs(target) + lookSpecs(target)
    }

    static func kindSpecs<T: AdjustTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("adjust.black-and-white", title: "Black & White",
                   summary: "Turns the picture grey, each hue as light as its weight; no weights removes it.",
                   kind: .edit, params: BWParams.self, schema: bw, example: .object([:]), availability: { ready($0) }) { _, _ -> Done in throw notBuilt },
            .typed("adjust.invert", title: "Invert", summary: "Turns Invert on or off: every colour becomes its opposite.",
                   kind: .edit, params: NoParams.self, schema: ParamSchema.none, example: .object([:]),
                   availability: { ready($0) }) { _, _ -> Done in throw notBuilt },
        ]
    }

    static func filterSpecs<T: AdjustTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        let pct = range("Percent, 0 to 100.", ImagingFilter.percent)
        func filter<P: Decodable & Sendable>(_ f: ImagingFilter, _ p: P.Type, _ summary: String, _ schema: ParamSchema,
                                             _ example: [String: JSONValue]) -> CommandSpec<T> {
            .typed("filter.\(f.id)", title: f.title, summary: summary, kind: .edit, params: p, schema: schema,
                   example: .object(example), availability: { ready($0, filter: true) }) { _, _ -> Done in throw notBuilt }
        }
        return [
            filter(.gaussianBlur(radius: 0), BlurParams.self, "Blurs the selected layer inside the selection.",
                   .object(["radius": range("Pixels, 0 to 250.", ImagingFilter.blurRadius)], required: ["radius"]), ["radius": .number(2)]),
            filter(.motionBlur(degrees: 0, distance: 0), MotionParams.self, "Smears the selected layer along an angle.",
                   .object(["degrees": range("Degrees, 0 to 360.", ImagingFilter.motionDegrees),
                            "distance": range("Pixels, 0 to 500.", ImagingFilter.motionDistance)], required: ["degrees", "distance"]),
                   ["degrees": .number(0), "distance": .number(10)]),
            filter(.sharpen(amount: 0, radius: 0, threshold: 0), SharpenParams.self, "Sharpens edges by an unsharp mask.",
                   .object(["amount": range("Percent, 0 to 500.", ImagingFilter.sharpenAmount),
                            "radius": range("Pixels, 0.1 to 250.", ImagingFilter.sharpenRadius),
                            "threshold": range("Levels, 0 to 255.", ImagingFilter.sharpenThreshold)],
                           required: ["amount", "radius", "threshold"]),
                   ["amount": .number(100), "radius": .number(1), "threshold": .number(0)]),
            filter(.reduceNoise(strength: 0, detail: 0), ReduceParams.self, "Smooths noise, keeping detail by the given percent.",
                   .object(["strength": pct, "detail": pct], required: ["strength", "detail"]), ["strength": .number(50), "detail": .number(50)]),
            filter(.addNoise(amount: 0, monochrome: false, seed: 0), NoiseParams.self, "Adds seeded noise, so a script repeats exactly.",
                   .object(["amount": pct, "monochrome": .optional(.boolean),
                            "seed": .optional(.integer("Picks the noise; 0 when left out.", minimum: 0))],
                           required: ["amount", "monochrome", "seed"]), ["amount": .number(10)]),
        ]
    }

    static func lookSpecs<T: AdjustTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("look.list", title: "Looks", summary: "The built-in looks, then the saved ones.", kind: .query,
                   params: NoParams.self, schema: ParamSchema.none, result: .array(of: row), example: .object([:])) { _, _ -> [LookRow] in throw notBuilt },
            .typed("look.apply", title: "Apply Look", summary: "Sets tone, adjustments and kinds from a look in one step.",
                   kind: .edit, params: LookID.self, schema: id, example: .object(["id": .string("bw")]),
                   availability: { ready($0) }) { _, _ -> Done in throw notBuilt },
            .typed("look.save", title: "Save Look", summary: "Saves the picture's tone, adjustments and kinds as a look.",
                   kind: .file, params: LookName.self, schema: name,
                   result: .object(["id": .string("The saved look's id.")], required: ["id"]),
                   example: .object(["name": .string("Mine")])) { _, _ -> LookID in throw notBuilt },
            .typed("look.delete", title: "Delete Look", summary: "Deletes a saved look; a built-in look can't be deleted.",
                   kind: .file, params: LookID.self, schema: id, example: .object(["id": .string("mine")])) { _, _ -> Done in throw notBuilt },
        ]
    }

    /// Available unless the target says why not; a filter also needs `filterHelp` nil.
    static func ready<T: AdjustTarget>(_ t: T, filter: Bool = false) -> Availability {
        if let help = t.adjustHelp ?? (filter ? t.filterHelp : nil) { return .unavailable(help) }
        return .available
    }
}
