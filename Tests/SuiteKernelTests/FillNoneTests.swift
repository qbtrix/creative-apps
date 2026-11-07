// FillNoneTests.swift (gradient-fill, gap audit C3): "no fill" beside the fill. `fill.type` none clears a target that
// can go without a fill as one undo step, a type back paints the kept fill as one step, `fill.read` reports "none",
// the stop and angle commands wait for a paint, and a target that can't go without a fill refuses with its reason.
import Testing
import SuiteKernel

/// One layer that may have no fill; its history keeps the fill and the flag together, so undo brings both back.
struct NoneDoc: GradientFillTarget {
    struct Paint: Sendable { var fill: Fill; var empty: Bool }
    var paint = Paint(fill: .solid(FillColor(r: 1, g: 0, b: 0, a: 0.5)), empty: false), history = History<Paint>()
    let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    var fillSelection: FillSelection? { FillSelection(fill: paint.fill, box: box, isEmpty: paint.empty) }
    var fillHelp: String? { nil }
    mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        history.record(name, paint, key: drag.map { "\(name):\($0)" }); paint = Paint(fill: fill, empty: false)
    }
    mutating func clearFill(name: String) throws { history.record(name, paint); paint.empty = true }
    mutating func undo() -> Bool {
        var current = paint
        let moved = history.undo { old in defer { current = old }; return current }
        paint = current
        return moved
    }
}

/// A target that always has a fill: it takes the protocol's default `clearFill`.
struct AlwaysFilled: GradientFillTarget {
    var fill = Fill.solid(.white)
    var fillSelection: FillSelection? { FillSelection(fill: fill, box: Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)) }
    var fillHelp: String? { nil }
    mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws { self.fill = fill }
}

@Suite struct FillNoneTests {
    static let catalog = try? CommandCatalog(app: "test", GradientCommands.specs(NoneDoc.self), history: { $0.history })
    static let none: JSONValue = .object(["type": .string("none")])

    @Test func noneClearsAndATypeBringsTheFillBack() throws {
        let catalog = try #require(Self.catalog)
        var doc = NoneDoc()
        let cleared = try catalog.run("fill.type", params: Self.none, on: &doc)
        #expect(doc.paint.empty && cleared.undoStep == "Fill Type")
        #expect(try catalog.run("fill.read", params: .object([:]), on: &doc).result == .object(["type": .string("none"), "stops": .array([]), "angle": .null]))
        _ = try catalog.run("fill.type", params: .object(["type": .string("solid")]), on: &doc)
        #expect(!doc.paint.empty && doc.paint.fill == .solid(FillColor(r: 1, g: 0, b: 0, a: 0.5)) && doc.history.steps.count == 2)
        #expect(doc.undo() && doc.paint.empty)
    }
    @Test func stopsAndAngleWaitForAPaint() throws {
        let catalog = try #require(Self.catalog)
        var doc = NoneDoc()
        doc.paint = .init(fill: .linear(stops: [GradientStop(offset: 0, color: .black), GradientStop(offset: 1, color: .white)],
                                        start: Point(x: 0, y: 50), end: Point(x: 100, y: 50)), empty: true)
        for id in ["fill.stop-add", "fill.stop-move", "fill.stop-remove", "fill.stop-color", "fill.angle"] {
            #expect(catalog.availability(id, on: doc) == .unavailable(GradientCommands.noneHelp), "\(id)")
        }
        #expect(catalog.availability("fill.type", on: doc) == .available)
    }
    @Test func aTargetThatAlwaysHasAFillRefusesNone() throws {
        let catalog = try CommandCatalog(app: "test", GradientCommands.specs(AlwaysFilled.self), history: { _ in History<Int>() })
        var doc = AlwaysFilled()
        #expect(throws: CatalogError.failed(id: "fill.type", message: GradientRules.noFillHelp)) {
            try catalog.run("fill.type", params: Self.none, on: &doc)
        }
        #expect(FillType.paints == [.solid, .linear, .radial] && FillType.allCases.contains(.none))
    }
}
