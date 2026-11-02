// FlareLayersFilesGateTests.swift: the layers-files quality gate (#5841). `flare new` honours the preset and
// background it is given and refuses a preset no one has; every layer command runs on the layer its params name,
// not only on the catalog example's layer-1; a .flare with no scenes is refused at open as damaged.
import FlareCore
import Foundation
@testable import FlareModel
import SuiteKernel
import Testing

@Suite struct FlareLayersFilesGateTests {
    @Test func newTakesThePresetAndBackgroundItIsGiven() throws {
        let square = try #require(CanvasPreset.all.first { $0.name == "Square" })
        let doc = try FlareHeadless.new(.object(["preset": .string("Square"), "background": .string("#FF0000")]))
        let scene = try #require(doc.workspace.selectedScene)
        #expect((scene.width, scene.height, scene.fps, scene.durationFrames)
            == (square.width, square.height, square.fps, square.durationFrames))
        #expect(scene.background == FlareColor(r: 1, g: 0, b: 0))
        let sized = try #require(try FlareHeadless.new(.object(["preset": .string("Square"), "width": .number(300)])).workspace.selectedScene)
        #expect((sized.width, sized.height) == (300, square.height))
    }

    @Test func newRefusesAPresetOrBackgroundItCantRead() {
        #expect { try FlareHeadless.new(.object(["preset": .string("Bogus")])) } throws: { error in
            guard case CatalogError.failed(id: "new", let message) = error else { return false }
            return message.contains("Bogus") && message.contains("Square")
        }
        #expect(throws: CatalogError.failed(id: "new", message: "Pick a valid background color.")) {
            try FlareHeadless.new(.object(["background": .string("red")]))
        }
        var ws = FlareWorkspace(services: .built)
        #expect(throws: CatalogError.self) { _ = try FlareWorkspace.catalog.run("file.new", params: .object(["preset": .string("Bogus")]), on: &ws) }
        #expect(ws.document == nil)
    }

    /// A document with layers layer-8 and layer-7 (on top): the catalog examples all name layer-1.
    static func layerSeven() throws -> FlareHeadless {
        var doc = try FlareHeadless.new(.null)
        for (id, name) in [("layer-8", "Ground"), ("layer-7", "Ball")] {
            let add: JSONValue = .object(["sceneID": .string("scene-1"), "layer": try JSONValue(encoding: Layer(id: id, name: name))])
            _ = try FlareHeadless.catalog.run("layer.add", params: add, on: &doc)
        }
        return doc
    }

    @Test(arguments: [
        ("layer.rename", ["name": JSONValue.string("Hero")]),
        ("layer.set-flags", ["isLocked": .bool(true)]),
        ("layer.duplicate", [:]),
        ("layer.reorder", ["toIndex": .number(0)]),
        ("shape.add", ["shape": try! JSONValue(encoding: FlareShape(points: [.init(x: 0, y: 0), .init(x: 9, y: 0), .init(x: 9, y: 9)]))]),
        ("layer.remove", [:]),
    ])
    func everyLayerCommandRunsOnTheLayerItNames(_ id: String, _ extra: [String: JSONValue]) throws {
        var doc = try Self.layerSeven()
        let before = doc.workspace.document
        #expect(FlareHeadless.catalog.availability(id, on: doc) == .available, "\(id)")
        let params = JSONValue.object(extra.merging(["sceneID": .string("scene-1"), "layerID": .string("layer-7")]) { a, _ in a })
        _ = try FlareHeadless.catalog.run(id, params: params, on: &doc)
        #expect(doc.workspace.document != before, "\(id)")
    }

    @Test func aLayerThatIsntThereIsRefusedByTheRunAndChangesNothing() throws {
        var doc = try Self.layerSeven()
        let before = doc.workspace.document
        let params: JSONValue = .object(["sceneID": .string("scene-1"), "layerID": .string("layer-99"), "name": .string("X")])
        #expect(throws: CatalogError.failed(id: "layer.rename", message: "This layer is no longer in the document.")) {
            try FlareHeadless.catalog.run("layer.rename", params: params, on: &doc)
        }
        #expect(doc.workspace.document == before)
    }

    @Test func aFileWithNoScenesIsRefusedAtOpenAsDamaged() throws {
        let one = try FlareFormat.encode(Document(scenes: [Scene(id: "scene-1", name: "Scene 1")]))
        var json = try #require(try JSONSerialization.jsonObject(with: one) as? [String: Any])
        var document = try #require(json["document"] as? [String: Any])
        document["scenes"] = [Any]()
        json["document"] = document
        let none = try JSONSerialization.data(withJSONObject: json)
        let damaged = "This file is damaged: it has no scenes."
        #expect(FlareWorkspace.decodeFile(none) == .failure(.invalid(FlareWorkspace.noScenes)))
        #expect { try FlareHeadless.open(none, name: "empty.flare") } throws: { error in
            error as? CatalogError == .failed(id: "open", message: damaged)
        }
        var ws = FlareWorkspace(services: .built)
        #expect(throws: (any Error).self) { try ws.open(none, named: "empty.flare") }
        #expect(ws.document == nil && ws.loadState == .failed(damaged))
    }
}
