// GradientCommandsTests.swift (gradient-fill GF-1 written, GF-6 turns on): the eight fill commands on a test
// target with a kernel `History`. Each edit run records one step named its title, a drag is one step, and every
// why-not reads. The spec shape check runs now; the rest are disabled by name until GF-6 builds the bodies.
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
    @Test(.disabled("waits on GF-6")) func oneStepPerRun() throws {
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
    @Test(.disabled("waits on GF-6")) func dragIsOneStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = FillDoc(fill: Self.linear())
        for sample in 0..<120 {
            let params: JSONValue = .object(["index": .number(1), "offset": .number(0.5 - Double(sample) / 480), "drag": .string("d1")])
            _ = try catalog.run("fill.stop-move", params: params, on: &doc)
        }
        #expect(doc.history.steps == ["Move Gradient Stop"])
        #expect(doc.undo() && doc.fill.stops.map(\.offset) == [0, 0.5, 1])
    }
    @Test(.disabled("waits on GF-6")) func angleNeedsLinear() throws {
        let catalog = try #require(Self.catalog)
        let radial = FillDoc(fill: .radial(stops: Self.linear().stops, center: Point(x: 50, y: 50), radius: 70))
        #expect(catalog.availability("fill.angle", on: radial) == .unavailable("Angle is for a linear gradient."))
        #expect(catalog.availability("fill.angle", on: FillDoc(fill: Self.linear())) == .available)
    }
    @Test(.disabled("waits on GF-6")) func stopRemoveNeedsThree() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.availability("fill.stop-remove", on: FillDoc(fill: Self.linear([0, 1]))) == .unavailable(GradientRules.stopHelp))
        #expect(catalog.availability("fill.stop-remove", on: FillDoc(fill: Self.linear())) == .available)
    }
    @Test(.disabled("waits on GF-6")) func intentCommandRoundTrips() throws {
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
}
