// AdjustCommands.swift (adjust-everywhere AJ-1 specs with real ids, schemas and
// availability; AJ-6 bodies): the commands an app adds with
// `+ AdjustCommands.specs(<X>Workspace.self)`. adjust.black-and-white (no
// weights removes it) and adjust.invert (a toggle) set the kinds, filter.<id> runs one filter on the selected
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

    /// A run's refusal for `id`, in words.
    static func refuse(_ id: String, _ why: String) -> CatalogError { .unavailable(id: id, why: why) }

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
                   kind: .edit, params: BWParams.self, schema: bw, example: .object([:]), availability: { ready($0) }) { t, p -> Done in
                var kinds = t.kinds
                let at = kinds.firstIndex { if case .blackAndWhite = $0 { true } else { false } }
                if let at { kinds.remove(at: at) }
                if let w = p.weights { kinds.insert(.blackAndWhite(w), at: at ?? kinds.endIndex) }
                try t.setKinds(kinds, name: "Black & White")
                return Done()
            },
            .typed("adjust.invert", title: "Invert", summary: "Turns Invert on or off: every colour becomes its opposite.",
                   kind: .edit, params: NoParams.self, schema: ParamSchema.none, example: .object([:]),
                   availability: { ready($0) }) { t, _ -> Done in
                let kinds = t.kinds.contains(.invert) ? t.kinds.filter { $0 != .invert } : t.kinds + [.invert]
                try t.setKinds(kinds, name: "Invert")
                return Done()
            },
        ]
    }

    static func filterSpecs<T: AdjustTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        let pct = range("Percent, 0 to 100.", ImagingFilter.percent)
        func filter<P: Decodable & Sendable>(_ f: ImagingFilter, _ p: P.Type, _ summary: String, _ schema: ParamSchema,
                                             _ example: [String: JSONValue],
                                             _ make: @escaping @Sendable (P) -> ImagingFilter) -> CommandSpec<T> {
            .typed("filter.\(f.id)", title: f.title, summary: summary, kind: .edit, params: p, schema: schema,
                   example: .object(example), availability: { ready($0, filter: true) }) { t, p -> Done in
                let made = make(p)
                try t.applyFilter(made, name: made.title)
                return Done()
            }
        }
        return [
            filter(.gaussianBlur(radius: 0), BlurParams.self, "Blurs the selected layer inside the selection.",
                   .object(["radius": range("Pixels, 0 to 250.", ImagingFilter.blurRadius)], required: ["radius"]), ["radius": .number(2)]) { .gaussianBlur(radius: $0.radius) },
            filter(.motionBlur(degrees: 0, distance: 0), MotionParams.self, "Smears the selected layer along an angle.",
                   .object(["degrees": range("Degrees, 0 to 360.", ImagingFilter.motionDegrees),
                            "distance": range("Pixels, 0 to 500.", ImagingFilter.motionDistance)], required: ["degrees", "distance"]),
                   ["degrees": .number(0), "distance": .number(10)]) { .motionBlur(degrees: $0.degrees, distance: $0.distance) },
            filter(.sharpen(amount: 0, radius: 0, threshold: 0), SharpenParams.self, "Sharpens edges by an unsharp mask.",
                   .object(["amount": range("Percent, 0 to 500.", ImagingFilter.sharpenAmount),
                            "radius": range("Pixels, 0.1 to 250.", ImagingFilter.sharpenRadius),
                            "threshold": range("Levels, 0 to 255.", ImagingFilter.sharpenThreshold)],
                           required: ["amount", "radius", "threshold"]),
                   ["amount": .number(100), "radius": .number(1), "threshold": .number(0)]) {
                .sharpen(amount: $0.amount, radius: $0.radius, threshold: $0.threshold)
            },
            filter(.reduceNoise(strength: 0, detail: 0), ReduceParams.self, "Smooths noise, keeping detail by the given percent.",
                   .object(["strength": pct, "detail": pct], required: ["strength", "detail"]), ["strength": .number(50), "detail": .number(50)]) {
                .reduceNoise(strength: $0.strength, detail: $0.detail)
            },
            filter(.addNoise(amount: 0, monochrome: false, seed: 0), NoiseParams.self, "Adds seeded noise, so a script repeats exactly.",
                   .object(["amount": pct, "monochrome": .optional(.boolean),
                            "seed": .optional(.integer("Picks the noise; 0 when left out.", minimum: 0))],
                           required: ["amount", "monochrome", "seed"]), ["amount": .number(10)]) {
                .addNoise(amount: $0.amount, monochrome: $0.monochrome ?? false, seed: UInt64(clamping: $0.seed ?? 0))
            },
        ]
    }

    static func lookSpecs<T: AdjustTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("look.list", title: "Looks", summary: "The built-in looks, then the saved ones.", kind: .query,
                   params: NoParams.self, schema: ParamSchema.none, result: .array(of: row), example: .object([:])) { t, _ -> [LookRow] in
                LookPreset.all(in: t.looks).map { LookRow(id: $0.id, name: $0.name, builtIn: $0.builtIn) }
            },
            .typed("look.apply", title: "Apply Look", summary: "Sets tone, adjustments and kinds from a look in one step.",
                   kind: .edit, params: LookID.self, schema: id, example: .object(["id": .string("bw")]),
                   availability: { ready($0) }) { t, p -> Done in
                guard let look = LookPreset.find(p.id, in: t.looks) else { throw refuse("look.apply", "There is no look \u{201C}\(p.id)\u{201D}.") }
                try t.applyLook(look, name: "Apply Look")
                return Done()
            },
            .typed("look.save", title: "Save Look", summary: "Saves the picture's tone, adjustments and kinds as a look.",
                   kind: .file, params: LookName.self, schema: name,
                   result: .object(["id": .string("The saved look's id.")], required: ["id"]),
                   example: .object(["name": .string("Mine")])) { t, p -> LookID in
                let name = p.name
                guard !name.allSatisfy(\.isWhitespace) else { throw refuse("look.save", "Give the look a name.") }
                guard !LookPreset.nameTaken(name, in: t.looks) else {
                    throw refuse("look.save", "You already have a look named \u{201C}\(name)\u{201D}.")
                }
                let now = t.currentLook
                let look = LookPreset(id: LookPreset.newID(name, in: t.looks), name: name,
                                      tone: now.tone, adjust: now.adjust, kinds: now.kinds)
                try stored("look.save") { () throws(SuiteError) in try t.looks.save(try record(look)) }
                return LookID(id: look.id)
            },
            .typed("look.delete", title: "Delete Look", summary: "Deletes a saved look; a built-in look can't be deleted.",
                   kind: .file, params: LookID.self, schema: id, example: .object(["id": .string("mine")])) { t, p -> Done in
                if BuiltInLooks.look(p.id) != nil { throw refuse("look.delete", "A built-in look can't be deleted.") }
                guard LookPreset.find(p.id, in: t.looks) != nil else {
                    throw refuse("look.delete", "There is no saved look \u{201C}\(p.id)\u{201D}.")
                }
                try stored("look.delete") { () throws(SuiteError) in try t.looks.delete(id: p.id, kind: LookPreset.recordKind) }
                return Done()
            },
        ]
    }

    /// Runs a store call for command `id`; a store refusal becomes the command's, in the store's words.
    static func stored(_ id: String, _ body: () throws(SuiteError) -> Void) throws(CatalogError) {
        do { try body() } catch { throw refuse(id, error.message) }
    }

    /// `look` as a store record; an encoding failure becomes a store error.
    static func record(_ look: LookPreset) throws(SuiteError) -> PresetRecord {
        do { return try look.record() } catch { throw .ioFailed(String(describing: error)) }
    }

    /// Available unless the target says why not; a filter also needs `filterHelp` nil.
    static func ready<T: AdjustTarget>(_ t: T, filter: Bool = false) -> Availability {
        if let help = t.adjustHelp ?? (filter ? t.filterHelp : nil) { return .unavailable(help) }
        return .available
    }
}
