// FakeCanvasFillTests.swift (gradient-fill GF-9): the fake app takes fills. A fill survives save and open, a locked
// rect refuses with its reason, a rect with no fill saves the JSON it always did, and RJ-X30's drag is one undo step.
import Foundation
import Testing
import SuiteKernel

@Suite struct FakeCanvasFillTests {
    let catalog = FakeCanvasDocument.catalog
    /// `fill.gradient`'s params: linear at 45°, blue, white and black.
    static let gradient = JSONValue.object(["type": .string("linear"), "angle": .number(45), "stops": .array([
        .object(["offset": .number(0), "r": .number(0), "g": .number(0), "b": .number(1), "a": .number(1)]),
        .object(["offset": .number(0.5), "r": .number(1), "g": .number(1), "b": .number(1), "a": .number(1)]),
        .object(["offset": .number(1), "r": .number(0), "g": .number(0), "b": .number(0), "a": .number(1)])])])
    /// One free rect with no fill, as RJ-X30's `one.fake` reads.
    static let plain = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 10, y: 10, w: 100, h: 60)], selection: 1)

    @Test func theFakeListsTheFillCommands() {
        let fill = GradientCommands.specs(FakeCanvasDocument.self).map(\.id)
        #expect(fill.count == 8 && fill.allSatisfy(catalog.ids.contains))
    }

    @Test func fillSurvivesSaveAndOpen() throws {
        var doc = FakeCanvasDocument.fixture
        _ = try catalog.run("fill.gradient", params: Self.gradient, on: &doc)
        let opened = try FakeCanvasDocument.open(doc.save(), name: "canvas.fake")
        #expect(opened.rects == doc.rects && opened.rects.first?.fill?.stops.count == 3)
        #expect(try opened.save() == doc.save())
        #expect(opened.rects.first?.fill != FakeCanvasDocument.fixture.rects.first?.fill)
    }

    @Test func lockedRefusesFill() {
        var doc = FakeCanvasDocument(rects: FakeCanvasDocument.fixture.rects, selection: 2)
        #expect(catalog.availability("fill.gradient", on: doc) == .unavailable("Unlock Rect 2 first."))
        // setFill refuses on its own too, not only through the catalog's availability check.
        #expect(throws: CatalogError.unavailable(id: "fill", why: "Unlock Rect 2 first.")) {
            try doc.setFill(.solid(.white), in: Rect(minX: 0, minY: 0, maxX: 80, maxY: 80), name: "Fill Type", drag: nil)
        }
        #expect(doc.rects == FakeCanvasDocument.fixture.rects && doc.history.steps.isEmpty)
    }

    @Test func oldJSONUnchanged() throws {
        let old = #"[{"h":60,"id":1,"locked":false,"name":"Rect 1","w":100,"x":10,"y":10}]"#
        #expect(String(decoding: try Self.plain.save(), as: UTF8.self) == old)
        let opened = try FakeCanvasDocument.open(Data(old.utf8), name: "one.fake")
        #expect(opened.rects == Self.plain.rects && opened.rects.first?.fill == nil)
        // A rect with no fill reads as solid black in its own box, so the fill commands still run on it.
        var doc = Self.plain
        #expect(doc.fillSelection == FillSelection(fill: .solid(.black), box: Rect(minX: 0, minY: 0, maxX: 100, maxY: 60)))
        _ = try catalog.run("fill.type", params: .object(["type": .string("radial")]), on: &doc)
        #expect(doc.rects.first?.fill?.stops.count == 2)
    }

    @Test func aStopDragOf120MovesIsOneUndoStep() throws {
        var doc = Self.plain
        _ = try catalog.run("fill.gradient", params: Self.gradient, on: &doc)
        let gradient = doc.rects.first?.fill
        for i in 1...120 {
            _ = try catalog.run("fill.stop-move", params: .object(["index": .number(1), "offset": .number(0.5 + Double(i) * 0.0025),
                                                                  "drag": .string("rj-x30")]), on: &doc)
        }
        #expect(doc.history.steps == ["Set Gradient", "Move Gradient Stop"])
        #expect(abs((doc.rects.first?.fill?.stops.dropFirst().first?.offset ?? 0) - 0.8) < 1e-9)
        _ = try catalog.run("edit.undo", params: .object([:]), on: &doc)
        #expect(doc.rects.first?.fill == gradient && doc.rects.first?.fill?.stops.dropFirst().first?.offset == 0.5)
        guard case .linear(_, let start, let end)? = doc.rects.first?.fill else { Issue.record("not linear"); return }
        #expect(start.x < end.x && start.y < end.y, "45° runs down and to the right")
    }
}
