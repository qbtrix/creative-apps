// FakeShapeTests.swift (shape-tools SH-8): the fake app draws shapes. A drawn star saves and reopens with its spec, a
// rect with no shape saves the JSON it always did, and RJ-X34 runs on this input: a polygon with 2 sides refuses with
// its reason and adds nothing, and the undo takes a star away in one step.
import Foundation
import Testing
import SuiteKernel

@Suite struct FakeShapeTests {
    let catalog = FakeCanvasDocument.catalog
    static let star: JSONValue = .object(["kind": .string("star"), "points": .number(5), "innerRatio": .number(0.5),
                                          "x": .number(0), "y": .number(0), "w": .number(100), "h": .number(100)])

    @Test func theFakeListsTheShapeCommands() {
        #expect(catalog.ids.contains("shape.draw") && catalog.ids.contains("tool.shape"))
        #expect(catalog.availability("shape.draw", on: FakeCanvasDocument()) == .available)
    }

    @Test func shapeSpecSaved() throws {
        var doc = FakeCanvasDocument()
        let outcome = try catalog.run("shape.draw", params: Self.star, on: &doc)
        #expect(outcome.undoStep == "Draw Star" && doc.selection == 1 && doc.rects.first?.name == "Star 1")
        let opened = try FakeCanvasDocument.open(doc.save(), name: "star.fake")
        #expect(opened.rects == doc.rects)
        #expect(opened.rects.first?.shape == ShapeSpec(kind: .star, points: 5, innerRatio: 0.5))
        #expect(String(decoding: try doc.save(), as: UTF8.self).contains(#""innerRatio":0.5,"kind":"star","points":5"#))
    }

    @Test func oldJSONUnchanged() throws {
        let old = #"[{"h":60,"id":1,"locked":false,"name":"Rect 1","w":100,"x":10,"y":10}]"#
        let plain = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 10, y: 10, w: 100, h: 60)])
        #expect(String(decoding: try plain.save(), as: UTF8.self) == old)
        #expect(try FakeCanvasDocument.open(Data(old.utf8), name: "one.fake").rects.first?.shape == nil)
    }

    @Test func pickingTheToolIsNoStep() throws {
        var doc = FakeCanvasDocument()
        _ = try catalog.run("tool.shape", params: .object(["kind": .string("polygon"), "sides": .number(6)]), on: &doc)
        #expect(doc.shapeTool == ShapeSpec(kind: .polygon, sides: 6) && doc.history.steps.isEmpty)
    }

    @Test func realJobX34() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RealJobs/fake/draw-star")
        guard case .object(let job) = try JSONValue(json: Data(contentsOf: folder.appendingPathComponent("draw-star.jobs.json"))),
              case .array(let steps)? = job["steps"] else {
            Issue.record("draw-star.jobs.json has no steps"); return
        }
        var doc = try FakeCanvasDocument.open(Data(contentsOf: folder.appendingPathComponent("input/empty.fake")), name: "empty.fake")
        #expect(doc.rects.isEmpty)
        // The packet's refused step: a polygon with 2 sides says why and adds nothing.
        var polygon = Self.star
        if case .object(var params) = polygon { params["kind"] = .string("polygon"); params["sides"] = .number(2); polygon = .object(params) }
        let refused = #expect(throws: CatalogError.self) { try catalog.run("shape.draw", params: polygon, on: &doc) }
        #expect(refused.map { String(describing: $0).contains("A polygon needs 3 to 64 sides.") } == true)
        #expect(doc.rects.isEmpty && doc.history.steps.isEmpty)
        for case .object(let step) in steps {
            guard case .string(let id)? = step["id"] else { continue }
            _ = try catalog.run(id, params: step["params"] ?? .object([:]), on: &doc)
        }
        #expect(doc.rects.count == 1 && doc.rects.first?.shape == ShapeSpec(kind: .star, points: 5, innerRatio: 0.5))
        // The job's undo took the second star in one step; one more takes the first.
        _ = try catalog.run("edit.undo", params: .object([:]), on: &doc)
        #expect(doc.rects.isEmpty)
    }
}
