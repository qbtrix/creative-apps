// StrokeCommandsTests.swift (stroke-style SS-1 written, SS-6 turned on): the nine stroke commands on a test target
// with a kernel `History`. Each edit records one step named its title, a width scrub is one step, every why-not
// reads, and dash and trim need a stroke (their bodies: StrokeDashTrimTests, SS-7).
import Testing
import SuiteKernel

/// One strokable layer, its history folding steps by drag token (`FillDoc`'s pattern).
struct StrokeDoc: StrokeTarget {
    var stroke: VectorStroke?, history = History<VectorStroke?>()
    var trimHelp: String? = nil
    var strokeHelp: String? { nil }
    var selectedStroke: VectorStroke? { stroke }
    mutating func setStroke(_ stroke: VectorStroke?, name: String, drag: String?) throws {
        history.record(name, self.stroke, key: drag.map { "\(name):\($0)" }); self.stroke = stroke
    }
    /// Undoes the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = stroke
        let moved = history.undo { old in defer { current = old }; return current }
        stroke = current
        return moved
    }
}

@Suite struct StrokeCommandsTests {
    static let catalog = (try? CommandCatalog(app: "test", StrokeCommands.specs(StrokeDoc.self), history: { $0.history }))
    static let titles = ["stroke.read": "Read Stroke", "stroke.add": "Add Stroke", "stroke.remove": "Remove Stroke",
                         "stroke.color": "Stroke Color", "stroke.width": "Stroke Width", "stroke.join": "Stroke Join",
                         "stroke.cap": "Stroke Cap", "stroke.dash": "Stroke Dash", "stroke.trim": "Trim Path"]

    @Test func specsAreTheNineWithTheirTitles() throws {
        #expect(String(reflecting: VectorStroke.self) == "FlareCore.Stroke")
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == Self.titles.keys.sorted())
        for (id, title) in Self.titles {
            let spec = try #require(catalog.spec(id))
            #expect(spec.kind == (id == "stroke.read" ? .query : .edit), "\(id)")
            if id != "stroke.read" { #expect(spec.title == title, "\(id)") }
        }
    }
    @Test func oneStepPerRun() throws {
        let catalog = try #require(Self.catalog)
        var doc = StrokeDoc(stroke: nil)
        let runs: [(String, JSONValue)] = [
            ("stroke.add", .object([:])),
            ("stroke.color", .object(["r": .number(1), "g": .number(0), "b": .number(0), "a": .number(1)])),
            ("stroke.width", .object(["width": .number(6)])),
            ("stroke.join", .object(["join": .string("round")])),
            ("stroke.cap", .object(["cap": .string("round")])),
            ("stroke.remove", .object([:])),
        ]
        for (count, (id, params)) in runs.enumerated() {
            let outcome = try catalog.run(id, params: params, on: &doc)
            #expect(outcome.undoStep == Self.titles[id] && doc.history.steps.count == count + 1, "\(id)")
        }
        #expect(doc.stroke == nil)
    }
    @Test func widthDragIsOneStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = StrokeDoc(stroke: VectorStroke(width: 2))
        for sample in 0..<120 {
            let params: JSONValue = .object(["width": .number(2 + Double(sample) / 30), "drag": .string("d1")])
            _ = try catalog.run("stroke.width", params: params, on: &doc)
        }
        #expect(doc.history.steps == ["Stroke Width"])
        #expect(doc.undo() && doc.stroke?.width == 2)
    }
    @Test func addNeedsNoStroke() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.availability("stroke.add", on: StrokeDoc(stroke: VectorStroke()))
            == .unavailable("The layer already has a stroke."))
        #expect(catalog.availability("stroke.add", on: StrokeDoc(stroke: nil)) == .available)
        #expect(catalog.availability("stroke.width", on: StrokeDoc(stroke: nil)) != .available)
    }
    @Test func dashAndTrimNeedAStroke() throws {
        let catalog = try #require(Self.catalog)
        for id in ["stroke.dash", "stroke.trim"] {
            #expect(catalog.availability(id, on: StrokeDoc(stroke: VectorStroke())) == .available, "\(id)")
            #expect(catalog.availability(id, on: StrokeDoc(stroke: nil)) == .unavailable("Add a stroke first."), "\(id)")
        }
    }
    @Test func trimHonoursHelp() throws {
        let catalog = try #require(Self.catalog)
        let why = "Trim paths are for animation, in Flare and Halo."
        #expect(catalog.availability("stroke.trim", on: StrokeDoc(stroke: VectorStroke(), trimHelp: why)) == .unavailable(why))
    }
    @Test func intentCommandRoundTrips() throws {
        let catalog = try #require(Self.catalog)
        let intents: [StrokeIntent] = [.add, .remove, .color(FillColor(r: 1, g: 0, b: 0), drag: "d"), .width(6, drag: nil),
                                       .join(.round), .cap(.square), .dash(.dashed, pattern: nil), .dash(.custom, pattern: [10, 4]),
                                       .trim(start: 0, end: 0.4, offset: 0.25, drag: "d")]
        let ids = ["stroke.add", "stroke.remove", "stroke.color", "stroke.width", "stroke.join", "stroke.cap",
                   "stroke.dash", "stroke.dash", "stroke.trim"]
        #expect(intents.map(\.command.id) == ids)
        for intent in intents {
            let spec = try #require(catalog.spec(intent.command.id))
            #expect(spec.params.validate(intent.command.params).isEmpty, "\(intent)")
        }
    }
}
