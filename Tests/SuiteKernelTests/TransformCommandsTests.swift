// TransformCommandsTests.swift (transform-tools TT-1 shape, TT-6 body): the six transform.* commands
// on a test target, run on TT-6's bodies.
import Testing
import SuiteKernel

/// A one-layer target: its box, why it can't transform or flip, and its undo history.
struct TransformTestTarget: TransformTarget {
    var item: TransformBox? = TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200))
    var help: String?
    var flipBlock: String?
    var history = History<TransformBox?>()

    var transformSelection: TransformBox? { item }
    var transformHelp: String? { help }
    var flipHelp: String? { flipBlock }

    mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        history.record(name, item, key: drag.map { "transform:\($0)" })
        item = t
    }

    mutating func undo() -> Bool {
        var current = item
        let undid = history.undo { old in defer { current = old }; return current }
        item = current
        return undid
    }

    static func catalog() throws -> CommandCatalog<TransformTestTarget> {
        try CommandCatalog(app: "test", TransformCommands.specs(TransformTestTarget.self)) { $0.history }
    }
}

@Suite struct TransformCommandsTests {
    /// The six ids, their kinds and titles, every id valid in one catalog.
    @Test func contractShape() throws {
        let catalog = try TransformTestTarget.catalog()
        #expect(catalog.ids == ["transform.flip", "transform.read", "transform.reset", "transform.rotate", "transform.scale", "transform.set"])
        let kinds = Dictionary(uniqueKeysWithValues: catalog.describeAll().map { ($0.id, $0.kind) })
        #expect(kinds == ["transform.read": .query, "transform.set": .edit, "transform.rotate": .edit,
                          "transform.scale": .edit, "transform.flip": .edit, "transform.reset": .edit])
        #expect(catalog.describe("transform.rotate")?.title == "Rotate" && catalog.describe("transform.reset")?.title == "Reset Rotation")
        var blocked = TransformTestTarget()
        blocked.help = "Select a layer first."
        #expect(catalog.availability("transform.rotate", on: blocked).why == "Select a layer first.")
    }

    /// Each edit records one step named its title; read changes nothing.
    @Test func eachEditIsOneNamedStep() throws {
        let catalog = try TransformTestTarget.catalog()
        let runs: [(String, JSONValue, String)] = [
            ("transform.set", .object(["w": .number(240)]), "Transform"),
            ("transform.rotate", .object(["degrees": .number(15)]), "Rotate"),
            ("transform.scale", .object(["sx": .number(2), "sy": .number(1)]), "Scale"),
            ("transform.flip", .object(["axis": .string("horizontal")]), "Flip Horizontal"),
            ("transform.flip", .object(["axis": .string("vertical")]), "Flip Vertical"),
            ("transform.reset", .object([:]), "Reset Rotation"),
        ]
        var doc = TransformTestTarget()
        for (n, (id, params, name)) in runs.enumerated() {
            #expect(try catalog.run(id, params: params, on: &doc).undoStep == name)
            #expect(doc.history.steps.count == n + 1)
        }
        let read = try catalog.run("transform.read", params: .object([:]), on: &doc)
        #expect(read.undoStep == nil && doc.history.steps.count == runs.count)
        #expect(doc.item?.degrees == 0 && doc.item?.flipX == false && doc.item?.box.width == 480)
    }

    /// 60 rotate samples under one drag token are one undo step, and rotate turns by its degrees, not to them.
    @Test func dragIsOneStep() throws {
        let catalog = try TransformTestTarget.catalog()
        var doc = TransformTestTarget()
        for _ in 0..<60 { _ = try catalog.run("transform.rotate", params: .object(["degrees": .number(1.5), "drag": .string("k1")]), on: &doc) }
        #expect(doc.history.steps == ["Rotate"] && abs((doc.item?.degrees ?? 0) - 90) < 1e-9)
        #expect(doc.undo() && doc.item?.degrees == 0 && !doc.undo())
    }

    /// Rotate is relative: two rotates by 100 land at -160, not at 100.
    @Test func rotateIsRelative() throws {
        let catalog = try TransformTestTarget.catalog()
        var doc = TransformTestTarget()
        for _ in 0..<2 { _ = try catalog.run("transform.rotate", params: .object(["degrees": .number(100)]), on: &doc) }
        #expect(abs((doc.item?.degrees ?? 0) + 160) < 1e-9 && doc.history.steps == ["Rotate", "Rotate"])
    }

    /// Flip says why not with the target's flipHelp, after transformHelp, and leaves the target as it was.
    @Test func flipHonoursHelp() throws {
        let catalog = try TransformTestTarget.catalog()
        var doc = TransformTestTarget()
        doc.flipBlock = "Text layers can't be mirrored."
        #expect(catalog.availability("transform.flip", on: doc).why == "Text layers can't be mirrored.")
        #expect(catalog.availability("transform.rotate", on: doc) == .available)
        #expect(throws: CatalogError.unavailable(id: "transform.flip", why: "Text layers can't be mirrored.")) {
            try catalog.run("transform.flip", params: .object(["axis": .string("vertical")]), on: &doc)
        }
        doc.help = "Select a layer first."
        #expect(catalog.availability("transform.flip", on: doc).why == "Select a layer first.")
        #expect(doc.item?.flipY == false && doc.history.steps.isEmpty)
    }

    /// A set to width 0 throws its sentence; a scale by 0 throws; neither records a step.
    @Test func setRefusesTinyBox() throws {
        let catalog = try TransformTestTarget.catalog()
        var doc = TransformTestTarget()
        #expect(throws: CatalogError.failed(id: "transform.set", message: "Width and height must be at least 1.")) {
            try catalog.run("transform.set", params: .object(["w": .number(0)]), on: &doc)
        }
        #expect(throws: CatalogError.self) { try catalog.run("transform.scale", params: .object(["sx": .number(0), "sy": .number(1)]), on: &doc) }
        #expect(doc.history.steps.isEmpty)
    }

    /// Read reports the box, turn and mirrors; with nothing selected an edit fails and records nothing.
    @Test func readsAndRefusesEmptySelection() throws {
        let catalog = try TransformTestTarget.catalog()
        var doc = TransformTestTarget()
        let read = try catalog.run("transform.read", params: .object([:]), on: &doc).result
        #expect(read == .object(["x": .number(100), "y": .number(80), "w": .number(200), "h": .number(120), "degrees": .number(0),
                                 "flipX": .bool(false), "flipY": .bool(false)]))
        doc.item = nil
        #expect(throws: CatalogError.failed(id: "transform.rotate", message: "Select something to transform first.")) {
            try catalog.run("transform.rotate", params: .object(["degrees": .number(15)]), on: &doc)
        }
        #expect(doc.history.steps.isEmpty)
    }

    /// Each intent's command is a registered id whose params validate and run.
    @Test func intentRoundTrips() throws {
        let catalog = try TransformTestTarget.catalog()
        let box = TransformBox(box: Rect(minX: 0, minY: 0, maxX: 40, maxY: 30), degrees: 10)
        let intents: [TransformIntent] = [.set(box, drag: "d"), .rotate(by: 15, drag: nil), .scale(sx: 2, sy: 3, anchor: .top, drag: nil),
                                          .flip(.vertical), .reset]
        var doc = TransformTestTarget()
        for intent in intents {
            let (id, params) = intent.command
            #expect(catalog.spec(id)?.params.validate(params).isEmpty == true)
            _ = try catalog.run(id, params: params, on: &doc)
        }
        var set = TransformTestTarget()
        _ = try catalog.run(TransformIntent.set(box, drag: nil).command.id, params: TransformIntent.set(box, drag: nil).command.params, on: &set)
        #expect(set.item?.box == box.box && set.item?.degrees == 10)
    }
}
