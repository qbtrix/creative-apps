// PathSelectTests.swift (#5072): `select.path` on a target that edits paths and selects areas. The path in edit,
// mapped to document space, becomes one polygon per contour (curves flattened, each closed), the first joined by the
// mode and the rest added, as one undo step; a path that encloses nothing, or no path, refuses.
import Testing
import SuiteKernel

/// A path in edit and an area selection, one history for both.
struct PathAreaDoc: PathEditTarget, AreaSelectTarget {
    var penDraft: PenDraft?, pathInEdit: PathInEdit?, anchorSelection = Selection<AnchorRef>(), pathHelp: String?
    var areaRecipe = AreaRecipe.empty, lastAreaRecipe: AreaRecipe?, areaHelp: String?, history = History<AreaRecipe>()
    mutating func addPath(_ path: VectorPath, name: String) throws -> String { "path-1" }
    mutating func setPath(_ path: VectorPath, name: String, drag: String?) throws {}
    mutating func setAreaRecipe(_ recipe: AreaRecipe) throws {
        history.record("Select", areaRecipe)
        areaRecipe = recipe
    }
}

@Suite struct PathSelectTests {
    static let catalog = (try? CommandCatalog(app: "test", PathSelect.specs(PathAreaDoc.self), history: { $0.history }))
    static func corner(_ x: Double, _ y: Double) -> VectorAnchor { VectorAnchor(point: Point(x: x, y: y)) }
    static func doc(_ contours: [VectorContour], toDocument: Matrix = .identity) -> PathAreaDoc {
        PathAreaDoc(pathInEdit: PathInEdit(id: "path-1", path: VectorPath(contours: contours), toDocument: toDocument))
    }
    static let triangle = VectorContour(anchors: [corner(0, 0), corner(10, 0), corner(0, 10)], closed: true)
    static func run(_ doc: inout PathAreaDoc, _ params: JSONValue = .object([:])) throws -> CommandOutcome? {
        try catalog?.run("select.path", params: params, on: &doc)
    }

    @Test func aTriangleSelectsItsPolygonInDocumentSpace() throws {
        var doc = Self.doc([Self.triangle], toDocument: Matrix(a: 1, b: 0, c: 0, d: 1, tx: 5, ty: 7))
        let outcome = try Self.run(&doc)
        #expect(outcome?.undoStep == "Select")
        let points = [(5.0, 7.0), (15, 7), (5, 17), (5, 7)].map { Point(x: $0.0, y: $0.1) }
        #expect(doc.areaRecipe.steps == [.shape(.polygon(points), .replace)])
        #expect(doc.history.steps.count == 1)
    }

    @Test func aCurveIsFlattenedAndAnOpenContourCloses() throws {
        let arc = VectorContour(anchors: [Self.corner(0, 0), VectorAnchor(point: Point(x: 20, y: 0), handleIn: Point(x: 20, y: -20), handleOut: nil, kind: .corner)],
                                closed: false)
        var doc = Self.doc([arc])
        _ = try Self.run(&doc)
        guard case .shape(.polygon(let points), .replace)? = doc.areaRecipe.steps.first else { Issue.record("no polygon"); return }
        #expect(points.count > 4)
        #expect(points.first == Point(x: 0, y: 0) && points.last == Point(x: 0, y: 0))
        #expect(points.contains { $0.y < -5 })
    }

    @Test func theModeJoinsTheFirstContourAndTheRestAreAdded() throws {
        var doc = Self.doc([Self.triangle, VectorContour(anchors: [Self.corner(20, 20), Self.corner(30, 20), Self.corner(20, 30)], closed: true)])
        doc.areaRecipe.apply(.shape(.rect(Rect(minX: 0, minY: 0, maxX: 50, maxY: 50)), .replace))
        _ = try Self.run(&doc, .object(["mode": .string("subtract")]))
        let modes = doc.areaRecipe.steps.compactMap { step -> AreaCombine? in if case .shape(_, let mode) = step { mode } else { nil } }
        #expect(modes == [.replace, .subtract, .add])
    }

    @Test func noAreaOrNoPathRefuses() throws {
        var line = Self.doc([VectorContour(anchors: [Self.corner(0, 0), Self.corner(10, 10)], closed: false)])
        #expect(throws: CatalogError.self) { try Self.run(&line) }
        #expect(line.history.steps.isEmpty)
        let none = PathAreaDoc()
        #expect(Self.catalog?.availability("select.path", on: none).why == PathSelect.noPathHelp)
        var busy = Self.doc([Self.triangle])
        busy.areaHelp = "Open an image first."
        #expect(Self.catalog?.availability("select.path", on: busy).why == "Open an image first.")
    }
}
