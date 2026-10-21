// AreaSelectCommands.swift (area-selection AR-1): the ten area commands a raster app adds with `+ AreaSelectCommands.specs(
// <X>Workspace.self)` and its `<X>Area+Kernel.swift`. Each sets the recipe once: one undo step. `AreaRecipe.apply` is AR-3's.

/// A document with an area selection: an app's workspace conforms in its `<X>Area+Kernel.swift`.
public protocol AreaSelectTarget: Sendable {
    /// Why nothing can be selected now (no document, no layer); nil when it can.
    var areaHelp: String? { get }
    /// The selection as the steps that make it; `.empty` when nothing is selected.
    var areaRecipe: AreaRecipe { get }
    /// The recipe before the last Deselect or replace, for Reselect; nil when there was none.
    var lastAreaRecipe: AreaRecipe? { get }
    /// Sets the selection's recipe as one undo step.
    mutating func setAreaRecipe(_ recipe: AreaRecipe) throws
}

/// The area select commands and the runner that takes them through a catalog.
public enum AreaSelectCommands {
    struct Empty: Codable, Sendable {}; struct XY: Codable, Sendable { var x, y: Double }
    struct RectParams: Codable, Sendable { var minX, minY, maxX, maxY: Double; var mode: AreaCombine? }
    struct PointsParams: Codable, Sendable { var points: [XY]; var mode: AreaCombine? }; struct RadiusParams: Codable, Sendable { var radius: Double }
    struct WandParams: Codable, Sendable { var x, y, tolerance: Double; var contiguous, allLayers: Bool?; var mode: AreaCombine? }
    /// Why a step after the shapes has nothing to change, and why Reselect has nothing to restore.
    static let emptyHelp = "Make a selection first.", reselectHelp = "There is no earlier selection to restore."
    static let number = ParamSchema.number()
    static let mode = ParamSchema.optional(.string("How the shape joins the selection; replace when left out.",
                                                   oneOf: AreaCombine.allCases.map(\.rawValue)))
    static let rect = ParamSchema.object(["minX": number, "minY": number, "maxX": number, "maxY": number, "mode": mode],
                                         required: ["minX", "minY", "maxX", "maxY", "mode"])
    static let points = ParamSchema.object(
        ["points": .array(of: .object(["x": number, "y": number], required: ["x", "y"]), minItems: 3, maxItems: 100_000), "mode": mode],
        required: ["points", "mode"])
    static let wand = ParamSchema.object(
        ["x": .number("The seed pixel's x."), "y": .number("The seed pixel's y."), "tolerance": .number("0 to 255 per channel.", minimum: 0, maximum: 255),
         "contiguous": .optional(.boolean), "allLayers": .optional(.boolean), "mode": mode],
        required: ["x", "y", "tolerance", "contiguous", "allLayers", "mode"])
    static func radius(_ what: String) -> ParamSchema { .object(["radius": .number(what, minimum: 0, maximum: 250)], required: ["radius"]) }
    static let box: JSONValue = .object(["minX": .number(10), "minY": .number(10), "maxX": .number(90), "maxY": .number(60)])
    static let triangle: JSONValue = .object(["points": .array([(10.0, 10.0), (90, 10), (50, 60)].map { .object(["x": .number($0.0), "y": .number($0.1)]) })])

    /// The ten area commands on `target`, in Select-menu order: the five shapes, the four steps, then Reselect;
    /// each an edit of one undo step.
    public static func specs<T: AreaSelectTarget>(_ target: T.Type) -> [CommandSpec<T>] {
        [
            .typed("select.rect", title: "Rectangle Select", summary: "Selects a rectangle, joined to the selection by a mode.",
                   kind: .edit, params: RectParams.self, schema: rect, example: box, availability: { ready($0) }) { t, p in
                try shape(&t, .rect(Rect(minX: p.minX, minY: p.minY, maxX: p.maxX, maxY: p.maxY)), p.mode) },
            .typed("select.ellipse", title: "Ellipse Select", summary: "Selects the ellipse inside a rectangle, joined by a mode.",
                   kind: .edit, params: RectParams.self, schema: rect, example: box, availability: { ready($0) }) { t, p in
                try shape(&t, .ellipse(Rect(minX: p.minX, minY: p.minY, maxX: p.maxX, maxY: p.maxY)), p.mode) },
            .typed("select.lasso", title: "Lasso Select", summary: "Selects inside a freehand outline, closed from its last point to its first.",
                   kind: .edit, params: PointsParams.self, schema: points, example: triangle, availability: { ready($0) }) { t, p in
                try shape(&t, .lasso(p.points.map { Point(x: $0.x, y: $0.y) }), p.mode) },
            .typed("select.polygon", title: "Polygon Select", summary: "Selects inside the polygon through clicked corners.",
                   kind: .edit, params: PointsParams.self, schema: points, example: triangle, availability: { ready($0) }) { t, p in
                try shape(&t, .polygon(p.points.map { Point(x: $0.x, y: $0.y) }), p.mode) },
            .typed("select.wand", title: "Magic Wand", summary: "Selects the pixels like the seed's within a tolerance, touching it unless not contiguous.",
                   kind: .edit, params: WandParams.self, schema: wand,
                   example: .object(["x": .number(20), "y": .number(20), "tolerance": .number(32)]), availability: { ready($0) }) { t, p in
                try shape(&t, .wand(seed: Point(x: p.x, y: p.y), tolerance: p.tolerance, contiguous: p.contiguous ?? true,
                                    allLayers: p.allLayers ?? false), p.mode) },
            .typed("select.invert", title: "Invert Selection", summary: "Selects everything that was not selected.", kind: .edit, params: Empty.self,
                   schema: ParamSchema.none, example: .object([:]), availability: { selected($0) }) { t, _ in try step(&t, .invert) },
            .typed("select.feather", title: "Feather", summary: "Softens the selection's edge over a radius in pixels, 0 to 250.",
                   kind: .edit, params: RadiusParams.self, schema: radius("Pixels the edge softens over."),
                   example: .object(["radius": .number(8)]), availability: { selected($0) }) { t, p in try step(&t, .feather(p.radius)) },
            .typed("select.expand", title: "Expand Selection", summary: "Moves the selection's edge out by a radius in pixels, 0 to 250.",
                   kind: .edit, params: RadiusParams.self, schema: radius("Pixels the edge moves out."),
                   example: .object(["radius": .number(2)]), availability: { selected($0) }) { t, p in try step(&t, .expand(p.radius)) },
            .typed("select.contract", title: "Contract Selection", summary: "Moves the selection's edge in by a radius in pixels, 0 to 250.",
                   kind: .edit, params: RadiusParams.self, schema: radius("Pixels the edge moves in."),
                   example: .object(["radius": .number(2)]), availability: { selected($0) }) { t, p in try step(&t, .expand(-p.radius)) },
            .typed("select.reselect", title: "Reselect", summary: "Restores the selection from before the last Deselect or new selection.",
                   kind: .edit, params: Empty.self, schema: ParamSchema.none, example: .object([:]),
                   availability: { ready($0, $0.lastAreaRecipe != nil, else: reselectHelp) }) { t, _ in try reselect(&t) },
        ]
    }

    /// Runs the area command `id` with `params` on `target` through a catalog of `specs`: the params checked, the
    /// availability read, one undo step. Throws `CatalogError` as the catalog does.
    public static func run<T: AreaSelectTarget>(_ id: String, _ params: JSONValue, on target: inout T) throws {
        _ = try CommandCatalog(app: "area", specs(T.self), history: { _ in History<Int>() }).run(id, params: params, on: &target)
    }

    static func ready<T: AreaSelectTarget>(_ target: T, _ ok: Bool = true, else why: String = "") -> Availability {
        if let help = target.areaHelp { return .unavailable(help) }
        return ok ? .available : .unavailable(why)
    }
    static func selected<T: AreaSelectTarget>(_ target: T) -> Availability { ready(target, !target.areaRecipe.isEmpty, else: emptyHelp) }
    static func shape<T: AreaSelectTarget>(_ t: inout T, _ shape: AreaShape, _ mode: AreaCombine?) throws -> Empty { try step(&t, .shape(shape, mode ?? .replace)) }
    /// The recipe with `step` applied and normalized, set as one undo step.
    static func step<T: AreaSelectTarget>(_ target: inout T, _ step: AreaRecipe.Step) throws -> Empty {
        var recipe = target.areaRecipe
        recipe.apply(step)
        try target.setAreaRecipe(recipe.normalized()); return Empty()
    }
    static func reselect<T: AreaSelectTarget>(_ target: inout T) throws -> Empty {
        guard let last = target.lastAreaRecipe else { throw CatalogError.unavailable(id: "select.reselect", why: reselectHelp) }
        try target.setAreaRecipe(last); return Empty()
    }
}
