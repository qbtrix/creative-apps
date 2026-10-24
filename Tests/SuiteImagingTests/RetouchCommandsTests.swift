// RetouchCommandsTests.swift (fill-heal FH-1 written, FH-6 on): the four fill
// and heal commands on a test target with a kernel `History`: their ids,
// titles and availability, each run being one undo step that undo reverses
// byte for byte, remove falling back to the selection, and the reasons a
// command can't run. Mutations (FH-6): SuiteImaging.RetouchCommands
// (`.undoRestoresBytes`, `.removeUsesSelection`).
import CoreRaster
import Testing
import SuiteKernel
import SuiteImaging

/// One pixel layer (or none), the merged picture, a selection, a paint colour, a clone source and a history of whole layers.
struct RetouchDoc: RetouchTarget {
    var pixels: PixelBuffer? = RetouchDoc.texture
    var merged: PixelBuffer? = RetouchDoc.texture
    var selection: Mask?
    var help: String?
    var color = RGBA(r: 0, g: 0, b: 1, a: 1)
    var offset: (dx: Int, dy: Int)? = (dx: -20, dy: 0)
    var history = History<PixelBuffer?>()
    var retouchHelp: String? { help }
    var targetPixels: PixelBuffer? { pixels }
    var mergedPixels: PixelBuffer? { merged }
    var selectionCoverage: Mask? { selection }
    var paintColor: RGBA { color }
    var cloneOffset: (dx: Int, dy: Int)? { offset }
    mutating func replaceTarget(_ p: PixelBuffer, name: String) throws { history.record(name, pixels); pixels = p }
    /// Undoes the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = pixels
        let moved = history.undo { old in defer { current = old }; return current }
        pixels = current
        return moved
    }

    /// 64 x 64: a blue-green texture with a red 8 x 8 square at (28, 28).
    static let texture: PixelBuffer? = {
        guard var p = try? PixelBuffer(width: 64, height: 64) else { return nil }
        for y in 0..<64 {
            for x in 0..<64 {
                let h = Float((x &* 73 &+ y &* 151 &+ (x * y) % 7) % 32) / 32
                let red = (28..<36).contains(x) && (28..<36).contains(y)
                try? p.setPixel(x: x, y: y, red ? RGBA(r: 1, g: 0, b: 0, a: 1) : RGBA(r: 0.1, g: 0.3 + 0.4 * h, b: 0.7 - 0.3 * h, a: 1))
            }
        }
        return p
    }()
}

@Suite struct RetouchCommandsTests {
    static let catalog = (try? CommandCatalog(app: "test", RetouchCommands.specs(RetouchDoc.self), history: { $0.history }))
    static let titles = ["fill.bucket": "Paint Bucket", "retouch.spot-heal": "Spot Heal", "retouch.heal": "Heal", "retouch.remove": "Remove"]
    static func points(_ xy: [(Double, Double)]) -> JSONValue { .array(xy.map { .object(["x": .number($0.0), "y": .number($0.1)]) }) }
    static let runs: [(String, JSONValue)] = [
        ("fill.bucket", .object(["x": .number(30), "y": .number(30), "tolerance": .number(32)])),
        ("retouch.spot-heal", .object(["x": .number(31), "y": .number(31), "size": .number(12), "seed": .number(3)])),
        ("retouch.heal", .object(["points": points([(44, 40), (50, 44)]), "size": .number(8)])),
        ("retouch.remove", .object(["points": points([(30, 30), (34, 34)]), "size": .number(12), "seed": .number(7)])),
    ]

    @Test func specsAreTheFourWithTheirTitles() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == Self.titles.keys.sorted())
        for (id, title) in Self.titles {
            let spec = try #require(catalog.spec(id))
            #expect(spec.kind == .edit && spec.title == title, "\(id)")
            #expect(spec.params.validate(spec.example).isEmpty, "\(id)")
            #expect(catalog.availability(id, on: RetouchDoc()) == .available, "\(id)")
        }
    }

    @Test func eachCommandIsOneStepThatUndoRestoresByteForByte() throws {
        let catalog = try #require(Self.catalog)
        for (id, params) in Self.runs {
            var doc = RetouchDoc()
            let outcome = try catalog.run(id, params: params, on: &doc)
            #expect(outcome.undoStep == Self.titles[id] && doc.history.steps == [Self.titles[id]], "\(id)")
            #expect(doc.pixels != RetouchDoc.texture, "\(id) changed nothing")
            #expect(doc.undo() && doc.pixels == RetouchDoc.texture, "\(id)")
        }
    }

    @Test func bucketPaintsTheColourAndAllLayersSamplesTheMerged() throws {
        let catalog = try #require(Self.catalog)
        var doc = RetouchDoc()
        _ = try catalog.run("fill.bucket", params: .object(["x": .number(30), "y": .number(30), "tolerance": .number(0)]), on: &doc)
        #expect(try doc.pixels?.pixel(x: 30, y: 30) == RGBA(r: 0, g: 0, b: 1, a: 1) && doc.pixels?.pixel(x: 2, y: 2) == RetouchDoc.texture?.pixel(x: 2, y: 2))
        var layered = RetouchDoc(pixels: try PixelBuffer(width: 64, height: 64))
        _ = try catalog.run("fill.bucket", params: .object(["x": .number(30), "y": .number(30), "tolerance": .number(0), "allLayers": .bool(true),
                                                             "color": .object(["r": .number(0), "g": .number(1), "b": .number(0), "a": .number(1)])]), on: &layered)
        #expect(try layered.pixels?.pixel(x: 30, y: 30) == RGBA(r: 0, g: 1, b: 0, a: 1) && layered.pixels?.pixel(x: 2, y: 2) == .clear)
    }

    @Test func removeWithNoPointsUsesTheSelection() throws {
        let catalog = try #require(Self.catalog)
        var doc = RetouchDoc(selection: try Mask.rectangle(width: 64, height: 64, x: 27, y: 27, w: 10, h: 10))
        _ = try catalog.run("retouch.remove", params: .object(["seed": .number(7)]), on: &doc)
        let pixels = try #require(doc.pixels)
        for y in 28..<36 { for x in 28..<36 { #expect(try pixels.pixel(x: x, y: y).r < 0.5, "(\(x), \(y)) still red") } }
        #expect(try pixels.pixel(x: 5, y: 5) == RetouchDoc.texture?.pixel(x: 5, y: 5))
        var nothing = RetouchDoc()
        #expect(throws: CatalogError.unavailable(id: "retouch.remove", why: RetouchCommands.removeHelp)) {
            try catalog.run("retouch.remove", params: .object([:]), on: &nothing)
        }
        #expect(nothing.history.steps.isEmpty && nothing.pixels == RetouchDoc.texture)
    }

    @Test func unavailableCommandsSayWhy() throws {
        let catalog = try #require(Self.catalog)
        let locked = RetouchDoc(help: "The layer is locked.")
        for id in catalog.ids { #expect(catalog.availability(id, on: locked) == .unavailable("The layer is locked."), "\(id)") }
        let noSource = RetouchDoc(offset: nil)
        #expect(catalog.availability("retouch.heal", on: noSource) == .unavailable(RetouchCommands.sourceHelp))
        #expect(RetouchCommands.sourceHelp == "Option-click a source first.")
        #expect(catalog.availability("retouch.spot-heal", on: noSource) == .available)
        var refused = RetouchDoc(help: "The layer is locked.")
        #expect(throws: CatalogError.self) { try catalog.run("retouch.spot-heal", params: Self.runs[1].1, on: &refused) }
        #expect(refused.history.steps.isEmpty)
    }
}
