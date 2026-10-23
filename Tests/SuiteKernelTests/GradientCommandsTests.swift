// GradientCommandsTests.swift (gradient-fill GF-6): the eight fill commands on a test target with a kernel `History`.
// Each edit run records one step named its title, a drag is one step, every why-not reads, `fill.read` reports the
// fill and `fill.gradient` sorts its stops and turns the line. Mutations: Tests/mutations/SuiteKernel.GradientCommands.json.
import Testing
import SuiteKernel

/// One fillable layer on a square box, its history folding steps by drag token (`FakeCanvasDocument.MoveRect`'s pattern).
struct FillDoc: GradientFillTarget {
    var fill: Fill, history = History<Fill>()
    let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    var fillSelection: FillSelection? { FillSelection(fill: fill, box: box) }
    var fillHelp: String? { nil }
    mutating func setFill(_ fill: Fill, in box: Rect, name: String, drag: String?) throws {
        history.record(name, self.fill, key: drag.map { "\(name):\($0)" }); self.fill = fill
    }
    /// Undoes the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = fill
        let moved = history.undo { old in defer { current = old }; return current }
        fill = current
        return moved
    }
}

@Suite struct GradientCommandsTests {
    static let catalog = (try? CommandCatalog(app: "test", GradientCommands.specs(FillDoc.self), history: { $0.history }))
    static let titles = ["fill.read": "Read Fill", "fill.type": "Fill Type", "fill.gradient": "Set Gradient",
                         "fill.stop-add": "Add Gradient Stop", "fill.stop-move": "Move Gradient Stop",
                         "fill.stop-remove": "Remove Gradient Stop", "fill.stop-color": "Gradient Stop Color", "fill.angle": "Gradient Angle"]
    /// A linear fill through stops at `offsets`, blue first, left to right.
    static func linear(_ offsets: [Double] = [0, 0.5, 1]) -> Fill {
        .linear(stops: offsets.map { GradientStop(offset: $0, color: $0 == 0 ? FillColor(r: 0, g: 0, b: 1) : .white) },
                start: Point(x: 0, y: 50), end: Point(x: 100, y: 50))
    }

    @Test func specsAreTheEightWithTheirTitles() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == Self.titles.keys.sorted())
        for (id, title) in Self.titles {
            let spec = try #require(catalog.spec(id))
            #expect(spec.kind == (id == "fill.read" ? .query : .edit), "\(id)")
            if id != "fill.read" { #expect(spec.title == title, "\(id)") }
        }
    }
    @Test func oneStepPerRun() throws {
        let catalog = try #require(Self.catalog)
        var doc = FillDoc(fill: Self.linear())
        let stop: JSONValue = .object(["offset": .number(0), "r": .number(1), "g": .number(0), "b": .number(0), "a": .number(1)])
        let runs: [(String, JSONValue)] = [
            ("fill.gradient", .object(["type": .string("linear"), "angle": .number(45), "stops": .array([stop, stop])])),
            ("fill.stop-add", .object(["offset": .number(0.5)])),
            ("fill.stop-color", .object(["index": .number(1), "r": .number(1), "g": .number(0), "b": .number(0), "a": .number(1)])),
            ("fill.angle", .object(["degrees": .number(90)])),
            ("fill.stop-remove", .object(["index": .number(1)])),
            ("fill.type", .object(["type": .string("radial")])),
        ]
        for (count, (id, params)) in runs.enumerated() {
            let outcome = try catalog.run(id, params: params, on: &doc)
            #expect(outcome.undoStep == Self.titles[id] && doc.history.steps.count == count + 1, "\(id)")
        }
    }
    @Test func dragIsOneStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = FillDoc(fill: Self.linear())
        for sample in 0..<120 {
            let params: JSONValue = .object(["index": .number(1), "offset": .number(0.5 - Double(sample) / 480), "drag": .string("d1")])
            _ = try catalog.run("fill.stop-move", params: params, on: &doc)
        }
        #expect(doc.history.steps == ["Move Gradient Stop"])
        #expect(doc.undo() && doc.fill.stops.map(\.offset) == [0, 0.5, 1])
    }
    @Test func angleNeedsLinear() throws {
        let catalog = try #require(Self.catalog)
        let radial = FillDoc(fill: .radial(stops: Self.linear().stops, center: Point(x: 50, y: 50), radius: 70))
        #expect(catalog.availability("fill.angle", on: radial) == .unavailable("Angle is for a linear gradient."))
        #expect(catalog.availability("fill.angle", on: FillDoc(fill: Self.linear())) == .available)
    }
    @Test func stopRemoveNeedsThree() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.availability("fill.stop-remove", on: FillDoc(fill: Self.linear([0, 1]))) == .unavailable(GradientRules.stopHelp))
        #expect(catalog.availability("fill.stop-remove", on: FillDoc(fill: Self.linear())) == .available)
    }
    @Test func intentCommandRoundTrips() throws {
        let catalog = try #require(Self.catalog)
        let intents: [GradientIntent] = [.type(.radial), .add(offset: 0.5), .move(index: 1, offset: 0.25, drag: "d"), .remove(index: 1),
                                         .color(index: 0, FillColor(r: 1, g: 0, b: 0), drag: nil), .angle(45, drag: "d")]
        let ids = ["fill.type", "fill.stop-add", "fill.stop-move", "fill.stop-remove", "fill.stop-color", "fill.angle"]
        #expect(intents.map(\.command.id) == ids)
        for intent in intents {
            let spec = try #require(catalog.spec(intent.command.id))
            #expect(spec.params.validate(intent.command.params).isEmpty, "\(intent)")
        }
    }
    @Test func readReportsTheFill() throws {
        let catalog = try #require(Self.catalog)
        var doc = FillDoc(fill: Self.linear([0, 1]))
        let read = try catalog.run("fill.read", params: .object([:]), on: &doc).result
        let blue: JSONValue = .object(["offset": .number(0), "r": .number(0), "g": .number(0), "b": .number(1), "a": .number(1)])
        let white: JSONValue = .object(["offset": .number(1), "r": .number(1), "g": .number(1), "b": .number(1), "a": .number(1)])
        #expect(read == .object(["type": .string("linear"), "stops": .array([blue, white]), "angle": .number(0)]))
        var radial = FillDoc(fill: .radial(stops: Self.linear().stops, center: Point(x: 50, y: 50), radius: 70))
        guard case .object(let fields) = try catalog.run("fill.read", params: .object([:]), on: &radial).result else { Issue.record("no object"); return }
        #expect(fields["angle"] == .null && fields["type"] == .string("radial"))
    }
    @Test func gradientSortsItsStopsAndTurnsTheLine() throws {
        let catalog = try #require(Self.catalog)
        var doc = FillDoc(fill: .solid(.white))
        func stop(_ offset: Double, _ r: Double) -> JSONValue {
            .object(["offset": .number(offset), "r": .number(r), "g": .number(0), "b": .number(0), "a": .number(1)])
        }
        let params: JSONValue = .object(["type": .string("linear"), "angle": .number(45), "stops": .array([stop(1, 1), stop(0, 0)])])
        _ = try catalog.run("fill.gradient", params: params, on: &doc)
        #expect(doc.fill.stops.map(\.offset) == [0, 1] && doc.fill.stops.last?.color == FillColor(r: 1, g: 0, b: 0))
        guard case .linear(_, let start, let end) = doc.fill else { Issue.record("not linear"); return }
        #expect(abs(start.x) < 1e-9 && abs(start.y) < 1e-9 && abs(end.x - 100) < 1e-9 && abs(end.y - 100) < 1e-9)
    }
    @Test func aBadStopIndexFails() throws {
        let catalog = try #require(Self.catalog)
        var doc = FillDoc(fill: Self.linear())
        #expect(throws: CatalogError.self) { try catalog.run("fill.stop-move", params: .object(["index": .number(9), "offset": .number(0.5)]), on: &doc) }
        #expect(doc.history.steps.isEmpty)
    }
    @Test func solidColorKeepsItsAlpha() throws {
        let catalog = try #require(Self.catalog)
        var doc = FillDoc(fill: .solid(.white))
        let params: JSONValue = .object(["index": .number(0), "r": .number(1), "g": .number(0), "b": .number(0), "a": .number(0.5)])
        #expect(catalog.availability("fill.stop-color", on: doc) == .available)
        _ = try catalog.run("fill.stop-color", params: params, on: &doc)
        #expect(doc.fill == .solid(FillColor(r: 1, g: 0, b: 0, a: 0.5)) && doc.history.steps == ["Gradient Stop Color"])
    }
}
