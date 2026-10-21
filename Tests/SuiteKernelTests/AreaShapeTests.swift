// AreaShapeTests.swift (area-selection AR-2 written, AR-3 turns on): the area recipe's rules, written from the packet
// before their bodies. The specs, the modifier mapping and the JSON round trip are AR-1's.
import Testing
import SuiteKernel

/// An area selection and the recipe the last replace or Deselect dropped, with a kernel history.
private struct AreaDoc: AreaSelectTarget {
    var areaRecipe = AreaRecipe.empty, lastAreaRecipe: AreaRecipe?, history = History<AreaRecipe>()
    var areaHelp: String? { nil }
    mutating func setAreaRecipe(_ recipe: AreaRecipe) throws {
        history.record("Select", areaRecipe)
        if !areaRecipe.isEmpty { lastAreaRecipe = areaRecipe }
        areaRecipe = recipe
    }
}

/// Each spec has `ids` in order, the `kind`, an example its params take and an object schema.
func expectSelectionSpecs<T>(_ specs: [CommandSpec<T>], _ ids: [String], _ kind: CommandKind) {
    #expect(specs.map(\.id) == ids)
    for spec in specs {
        #expect(spec.kind == kind && spec.params.validate(spec.example).isEmpty, "\(spec.id)")
        guard case .object(let fields) = spec.params.json else { Issue.record("\(spec.id) has no object schema"); continue }
        #expect(fields["type"] == .string("object"), "\(spec.id)")
    }
}

@Suite struct AreaShapeTests {
    static let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 80)
    static func rect(_ maxX: Double) -> JSONValue { .object(["minX": .number(0), "minY": .number(0), "maxX": .number(maxX), "maxY": .number(80)]) }

    /// AR-1: the ten specs build a catalog, each an edit with an object schema.
    @Test func areaSpecsHaveSchemas() throws {
        let specs = AreaSelectCommands.specs(AreaDoc.self)
        #expect(try CommandCatalog(app: "test", specs, history: { $0.history }).ids.count == 10)
        expectSelectionSpecs(specs, ["select.rect", "select.ellipse", "select.lasso", "select.polygon", "select.wand", "select.invert",
                                     "select.feather", "select.expand", "select.contract", "select.reselect"], .edit)
    }

    /// AR-1: Shift adds, Option subtracts, both intersect, and Command alone replaces.
    @Test func modifiersPickTheMode() {
        #expect(AreaCombine([]) == .replace && AreaCombine(.command) == .replace && AreaCombine(.shift) == .add)
        #expect(AreaCombine([.option, .command]) == .subtract && AreaCombine([.shift, .option, .command]) == .intersect)
    }

    /// AR-1: a recipe of every step kind, and a scope, come back from JSON equal.
    @Test func recipeAndScopeRoundTripThroughJSON() throws {
        let wand = AreaShape.wand(seed: Point(x: 4, y: 5), tolerance: 32, contiguous: false, allLayers: true), dots = [Point(x: 1, y: 2)]
        var recipe = AreaRecipe.empty
        for step: AreaRecipe.Step in [.shape(.rect(Self.box), .replace), .shape(.ellipse(Self.box), .add), .shape(.lasso(dots), .subtract),
                                      .shape(.polygon(dots), .intersect), .shape(wand, .add), .invert, .feather(8), .expand(-2)] { recipe.apply(step) }
        #expect(try JSONValue(encoding: recipe).decode(AreaRecipe.self) == recipe && recipe.steps.count == 8 && AreaRecipe.empty.isEmpty)
        #expect(try JSONValue(encoding: GroupScope(path: ["card", "face"])).decode(GroupScope.self) == GroupScope(path: ["card", "face"]))
    }

    /// A lasso and a polygon of three points close back to their first point, once.
    @Test func lassoAndPolygonClose() {
        let three = [Point(x: 0, y: 0), Point(x: 40, y: 0), Point(x: 20, y: 30)]
        var recipe = AreaRecipe.empty
        recipe.apply(.shape(.lasso(three), .replace))
        recipe.apply(.shape(.polygon(three), .add))
        #expect(recipe.normalized().steps == [.shape(.lasso(three + three.prefix(1)), .replace), .shape(.polygon(three + three.prefix(1)), .add)])
        #expect(recipe.normalized().normalized() == recipe.normalized())
    }

    /// A thousand samples 0.2 px apart simplify to under 50; points a pixel apart all stay.
    @Test func lassoDropsPointsUnderAPixel() {
        // A slow drag with a tremor, about 0.2 px a sample: 20 px right, then 20 px down.
        let tremor = { (i: Int) in Double(i % 2) * 0.2 }
        let dense = (0..<500).map { Point(x: Double($0) * 0.04, y: tremor($0)) } + (0..<500).map { Point(x: 20 + tremor($0), y: Double($0) * 0.04) }
        // Points exactly 1 px apart are kept: under a pixel is dropped, a pixel is not.
        let square = (0..<4).map { Point(x: Double($0), y: 0) } + (1..<4).map { Point(x: 3, y: Double($0)) }
        let kept = [dense, square].map { points -> [Point] in
            var recipe = AreaRecipe.empty
            recipe.apply(.shape(.lasso(points), .replace))
            if case .shape(.lasso(let kept), _)? = recipe.normalized().steps.first { return kept } else { return [] }
        }
        #expect(kept.first.map { $0.count < 50 && $0.count >= 3 } == true)
        #expect(kept.last?.count == square.count + 1)
    }

    /// Steps keep their order, a replace starts over, and invert twice is the recipe before.
    @Test func replaceStartsOverAndStepsKeepOrder() {
        var recipe = AreaRecipe.empty
        let steps: [AreaRecipe.Step] = [.shape(.rect(Self.box), .replace), .feather(4), .shape(.ellipse(Self.box), .subtract), .expand(-2)]
        steps.forEach { recipe.apply($0) }
        #expect(recipe.steps == steps)
        recipe.apply(.shape(.ellipse(Self.box), .replace))
        #expect(recipe.steps == [.shape(.ellipse(Self.box), .replace)])
        let inverted = { (r: AreaRecipe) -> AreaRecipe in var copy = r; copy.apply(.invert); return copy }
        #expect(inverted(inverted(recipe)) == recipe)
    }

    /// The commands join by mode, each one undo step, and Reselect restores the recipe a replace dropped.
    @Test func commandsJoinAndReselectRestores() throws {
        var doc = AreaDoc()
        try AreaSelectCommands.run("select.ellipse", Self.rect(100), on: &doc)
        let triangle: JSONValue = .array([(40.0, 60.0), (60, 60), (50, 90)].map { .object(["x": .number($0.0), "y": .number($0.1)]) })
        let steps: [(String, JSONValue)] = [("select.lasso", .object(["points": triangle, "mode": .string("subtract")])), ("select.invert", .object([:])),
                                            ("select.feather", .object(["radius": .number(8)])), ("select.contract", .object(["radius": .number(2)]))]
        for (id, params) in steps { try AreaSelectCommands.run(id, params, on: &doc) }
        let made = doc.areaRecipe
        #expect(made.steps.count == 5 && made.steps.suffix(3) == [.invert, .feather(8), .expand(-2)] && doc.history.steps.count == 5)
        try AreaSelectCommands.run("select.rect", Self.rect(10), on: &doc)
        try AreaSelectCommands.run("select.reselect", .object([:]), on: &doc)
        #expect(doc.areaRecipe == made)
    }

    /// A polygon keeps corners under a pixel apart, a closed lasso is not closed twice, and a shape that joins keeps
    /// the steps before it.
    @Test func polygonKeepsCornersAndClosedStaysClosed() {
        let tight = [Point(x: 0, y: 0), Point(x: 0.5, y: 0), Point(x: 0.5, y: 0.5), Point(x: 30, y: 30)]
        let closed = [Point(x: 0, y: 0), Point(x: 40, y: 0), Point(x: 20, y: 30), Point(x: 0, y: 0)]
        var recipe = AreaRecipe.empty
        recipe.apply(.shape(.polygon(tight), .replace))
        recipe.apply(.shape(.lasso(closed), .intersect))
        recipe.apply(.invert)
        #expect(recipe.normalized().steps == [.shape(.polygon(tight + tight.prefix(1)), .replace), .shape(.lasso(closed), .intersect), .invert])
    }
}
