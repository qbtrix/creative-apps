// PlaceCommandsTests.swift (placed-images PL-1 written, PL-7 turns on): the five place commands on a test target
// with a kernel `History`. A place is one step, a focus drag is one step, a fill uses the selected layer, and
// every why-not reads.
import Foundation
import Testing
import SuiteKernel

/// Layers that each may show a picture, one selected, its history holding the state each step replaced.
struct PlaceDoc: PlacedImageTarget {
    struct State: Hashable, Sendable { var layers: [String: PlacedImage] = [:], assets = PlacedAssets(), selected: String? }
    var state = State(), history = History<State>()
    var placeFormats: Set<PlacedFormat> = Set(PlacedFormat.allCases), placeFillBox: Rect?
    var placeHelp: String? { nil }
    var placeCanvas: Rect { Rect(minX: 0, minY: 0, maxX: 800, maxY: 600) }
    var placedSelection: (id: String, image: PlacedImage, asset: PlacedAsset)? {
        guard let id = state.selected, let image = state.layers[id], let asset = state.assets.byID[image.assetID] else { return nil }
        return (id, image, asset)
    }
    func rasterSize(_ data: Data, format: PlacedFormat) throws -> Size { Size(width: 1200, height: 400) }
    mutating func insertPlaced(_ asset: PlacedAsset, _ image: PlacedImage, name: String) throws -> String {
        history.record(name, state)
        let id = "layer\(state.layers.count + 1)"
        (state.layers[id], state.assets, state.selected) = (image, state.assets.adding(asset), id)
        return id
    }
    mutating func setPlaced(_ image: PlacedImage, asset: PlacedAsset?, name: String, drag: String?) throws {
        guard let id = state.selected else { return }
        history.record(name, state, key: drag.map { "\(name):\($0)" })
        (state.layers[id], state.assets) = (image, asset.map(state.assets.adding) ?? state.assets)
    }
}

@Suite struct PlaceCommandsTests {
    static let catalog = (try? CommandCatalog(app: "test", PlaceCommands.specs(PlaceDoc.self), history: { $0.history }))
    static let titles = ["place.read": "Read Placed Image", "place.image": "Place Image", "place.replace": "Replace Image",
                         "place.reset-size": "Reset Size", "place.focus": "Move Inside"]
    static let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 13])
    static let svg = Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="240" height="80"/>"#.utf8)
    static func place(_ data: Data, fill: Bool = false) -> JSONValue {
        guard case .object(var fields) = PlaceIntent.place(name: "wide.png", data: data, at: nil).command.params else { return .object([:]) }
        if fill { fields["fill"] = .bool(true) }
        return .object(fields)
    }

    @Test func specsAreTheFiveWithTheirTitles() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == Self.titles.keys.sorted())
        for (id, title) in Self.titles {
            let spec = try #require(catalog.spec(id))
            #expect(spec.kind == (id == "place.read" ? .query : .edit) && spec.title == title, "\(id)")
            #expect(spec.params.validate(spec.example).isEmpty, "\(id)")
        }
    }
    @Test func intentsMatchTheirSchemasAndSelectionWhyNot() throws {
        let catalog = try #require(Self.catalog)
        let intents: [PlaceIntent] = [.place(name: "a.png", data: Self.png, at: Point(x: 1, y: 2)), .replace(name: "b.png", data: Self.png),
                                      .resetSize, .focus(Point(x: 0.25, y: 0.5), drag: "d1")]
        for intent in intents {
            #expect(try #require(catalog.spec(intent.command.id)).params.validate(intent.command.params).isEmpty, "\(intent.command.id)")
        }
        for id in ["place.read", "place.replace", "place.reset-size", "place.focus"] {
            #expect(catalog.availability(id, on: PlaceDoc()) == .unavailable("Select a placed image first."), "\(id)")
        }
        #expect(catalog.availability("place.image", on: PlaceDoc()) == .available)
    }
    @Test func placeAndFocusDragAreOneStepEach() throws {
        let catalog = try #require(Self.catalog)
        var doc = PlaceDoc()
        #expect(try catalog.run("place.image", params: Self.place(Self.png), on: &doc) == CommandOutcome(
            result: .object(["id": .string("layer1")]), undoStep: "Place Image"))
        let fitted = try #require(doc.state.layers["layer1"]?.box)
        #expect(fitted.minX == 0 && fitted.width == 800 && abs(fitted.height - 800.0 / 3) < 1e-9 && abs(fitted.minY + fitted.maxY - 600) < 1e-9)
        #expect(doc.placedSelection?.asset.natural == Size(width: 1200, height: 400))
        if let id = doc.state.selected { doc.state.layers[id]?.box = Rect(minX: 0, minY: 0, maxX: 300, maxY: 300) }
        for n in 0..<30 {
            let focus = PlaceIntent.focus(Point(x: 0.5 - Double(n) / 116, y: 0.5), drag: "d1").command
            _ = try catalog.run(focus.id, params: focus.params, on: &doc)
        }
        #expect(doc.history.steps == ["Place Image", "Move Inside"] && doc.history.undoSteps.last?.payload.layers["layer1"]?.focus == Point(x: 0.5, y: 0.5))
    }
    @Test func fillUsesTheSelectedLayer() throws {
        let catalog = try #require(Self.catalog)
        let box = Rect(minX: 0, minY: 0, maxX: 300, maxY: 300)
        var doc = PlaceDoc(placeFillBox: box), bare = PlaceDoc()
        doc.state.selected = "rect"
        let outcome = try catalog.run("place.image", params: Self.place(Self.png, fill: true), on: &doc)
        #expect(outcome == CommandOutcome(result: .object(["id": .string("rect")]), undoStep: "Place Image"))
        #expect(doc.state.layers.keys.sorted() == ["rect"] && doc.state.layers["rect"]?.box == box && doc.history.steps.count == 1)
        #expect(throws: CatalogError.unavailable(id: "place.image", why: "Select a frame to fill.")) {
            try catalog.run("place.image", params: Self.place(Self.png, fill: true), on: &bare)
        }
    }
    @Test func refusesUnlistedFormatAndOver32MB() throws {
        let catalog = try #require(Self.catalog)
        var doc = PlaceDoc(placeFormats: [.png, .jpeg])
        #expect(throws: CatalogError.unavailable(id: "place.image", why: "Place takes PNG or JPEG files.")) {
            try catalog.run("place.image", params: Self.place(Data("plain text".utf8)), on: &doc)
        }
        #expect(throws: CatalogError.unavailable(id: "place.image", why: "Place takes PNG or JPEG files.")) {
            try catalog.run("place.image", params: Self.place(Self.svg), on: &doc)
        }
        #expect(throws: CatalogError.unavailable(id: "place.image", why: PlaceRules.sizeHelp)) {
            try catalog.run("place.image", params: Self.place(Self.png + Data(count: PlaceRules.maxBytes)), on: &doc)
        }
        #expect(doc.history.steps.isEmpty)
    }
    /// Each target's refusal names only the formats it takes (#6027).
    @Test func theFormatRefusalNamesTheTargetsFormats() {
        #expect(PlaceRules.formatHelp(for: [.png, .jpeg]) == "Place takes PNG or JPEG files.")
        #expect(PlaceRules.formatHelp(for: [.svg]) == "Place takes SVG files.")
        #expect(PlaceRules.formatHelp(for: Set(PlacedFormat.allCases)) == PlaceRules.formatHelp)
        #expect(PlaceRules.formatHelp(for: []) == PlaceRules.formatHelp)
    }
    @Test func naturalAspectHasNothingToMoveOrReset() throws {
        let catalog = try #require(Self.catalog)
        var doc = PlaceDoc()
        _ = try catalog.run("place.image", params: Self.place(Self.svg), on: &doc)
        let box = Rect(minX: 280, minY: 260, maxX: 520, maxY: 340)
        #expect(doc.state.layers["layer1"]?.box == box)
        #expect(catalog.availability("place.focus", on: doc) == .unavailable("The image fits its box; there is nothing to move."))
        #expect(catalog.availability("place.reset-size", on: doc) == .unavailable("The image already has its own shape."))
        let read = try catalog.run("place.read", params: .object([:]), on: &doc)
        let boxJSON = try JSONValue(encoding: box)
        #expect(read.undoStep == nil && read.result == .object(
            ["name": .string("wide.png"), "format": .string("svg"), "width": .number(240), "height": .number(80), "box": boxJSON,
             "focus": .object(["x": .number(0.5), "y": .number(0.5)]), "drawn": boxJSON]))
    }
    @Test func replaceAndResetAreOneStepEach() throws {
        let catalog = try #require(Self.catalog)
        var doc = PlaceDoc()
        _ = try catalog.run("place.image", params: Self.place(Self.svg), on: &doc)
        if let id = doc.state.selected { doc.state.layers[id]?.box = Rect(minX: 0, minY: 0, maxX: 300, maxY: 300) }
        let replace = PlaceIntent.replace(name: "wide.png", data: Self.png).command
        #expect(try catalog.run(replace.id, params: replace.params, on: &doc).undoStep == "Replace Image")
        #expect(doc.placedSelection?.asset.natural == Size(width: 1200, height: 400))
        #expect(try catalog.run("place.reset-size", params: .object([:]), on: &doc).undoStep == "Reset Size")
        #expect(doc.placedSelection?.image.box == Rect(minX: 0, minY: 100, maxX: 300, maxY: 200))
        #expect(doc.history.steps == ["Place Image", "Replace Image", "Reset Size"])
    }
    @Test func intentCommandsRoundTrip() throws {
        let intents: [PlaceIntent] = [.place(name: "a.png", data: Self.png, at: Point(x: 1, y: 2)), .place(name: "b.svg", data: Self.svg, at: nil),
                                      .replace(name: "c.png", data: Self.png), .resetSize, .focus(Point(x: 0.25, y: 0.5), drag: "d1")]
        for intent in intents { #expect(Self.intent(intent.command) == intent, "\(intent.command.id)") }
    }

    /// The intent a command's id and params name, read back by hand: what the panel, the drop and the rows sent.
    static func intent(_ command: (id: String, params: JSONValue)) -> PlaceIntent? {
        guard case .object(let f) = command.params else { return nil }
        func string(_ key: String) -> String? { if case .string(let s)? = f[key] { s } else { nil } }
        func number(_ key: String) -> Double? { if case .number(let n)? = f[key] { n } else { nil } }
        let file = string("name").flatMap { name in string("base64").flatMap { Data(base64Encoded: $0) }.map { (name, $0) } }
        let point = number("x").flatMap { x in number("y").map { Point(x: x, y: $0) } }
        switch command.id {
        case "place.image": return file.map { .place(name: $0.0, data: $0.1, at: point) }
        case "place.replace": return file.map { .replace(name: $0.0, data: $0.1) }
        case "place.reset-size": return f.isEmpty ? .resetSize : nil
        case "place.focus": return point.flatMap { p in string("drag").map { .focus(p, drag: $0) } }
        default: return nil
        }
    }
}
