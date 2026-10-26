// FakeStrokeTests.swift (stroke-style SS-8): the fake app takes strokes. A dashed, trimmed stroke survives save and
// open, a locked rect refuses with its reason, a rect with no stroke saves the JSON it always did, and RJ-X35's trim
// scrub is one undo step.
import Foundation
import Testing
import SuiteKernel

@Suite struct FakeStrokeTests {
    let catalog = FakeCanvasDocument.catalog
    /// One free rect with no fill or stroke, as RJ-X35's `one.fake` reads.
    static let plain = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 10, y: 10, w: 100, h: 60)], selection: 1)

    /// `doc` with a 4 pt dashed stroke on the selected rect.
    func dashed(_ doc: FakeCanvasDocument) throws -> FakeCanvasDocument {
        var doc = doc
        _ = try catalog.run("stroke.add", params: .object([:]), on: &doc)
        _ = try catalog.run("stroke.width", params: .object(["width": .number(4)]), on: &doc)
        _ = try catalog.run("stroke.dash", params: .object(["preset": .string("dashed")]), on: &doc)
        return doc
    }

    @Test func theFakeListsTheStrokeCommands() {
        let stroke = StrokeCommands.specs(FakeCanvasDocument.self).map(\.id)
        #expect(stroke.count == 9 && stroke.allSatisfy(catalog.ids.contains))
        #expect(catalog.availability("stroke.trim", on: Self.plain) == .unavailable("Add a stroke first."))
    }

    @Test func dashAndTrimSurviveSaveAndOpen() throws {
        var doc = try dashed(Self.plain)
        _ = try catalog.run("stroke.trim", params: .object(["start": .number(0.25), "end": .number(0.5), "offset": .number(0.1)]), on: &doc)
        let opened = try FakeCanvasDocument.open(doc.save(), name: "canvas.fake")
        #expect(opened.rects == doc.rects)
        #expect(try opened.save() == doc.save())
        let stroke = opened.rects.first?.stroke
        #expect(stroke?.width == 4 && stroke?.dash == [16, 8])
        #expect(stroke?.trim?.start == 0.25 && stroke?.trim?.end == 0.5 && stroke?.trim?.offset == 0.1, "fractions, not percentages")
        #expect(String(decoding: try doc.save(), as: UTF8.self).contains(#""stroke":{"#))
    }

    @Test func lockedRefusesStroke() {
        var doc = FakeCanvasDocument(rects: FakeCanvasDocument.fixture.rects, selection: 2)
        #expect(catalog.availability("stroke.add", on: doc) == .unavailable("Unlock Rect 2 first."))
        // setStroke refuses on its own too, not only through the catalog's availability check.
        #expect(throws: CatalogError.unavailable(id: "stroke", why: "Unlock Rect 2 first.")) {
            try doc.setStroke(VectorStroke(), name: "Add Stroke", drag: nil)
        }
        #expect(doc.rects == FakeCanvasDocument.fixture.rects && doc.history.steps.isEmpty)
    }

    @Test func oldJSONUnchanged() throws {
        let old = #"[{"h":60,"id":1,"locked":false,"name":"Rect 1","w":100,"x":10,"y":10}]"#
        #expect(String(decoding: try Self.plain.save(), as: UTF8.self) == old)
        let opened = try FakeCanvasDocument.open(Data(old.utf8), name: "one.fake")
        #expect(opened.rects == Self.plain.rects && opened.rects.first?.stroke == nil)
    }

    @Test func aTrimScrubOf60SamplesIsOneUndoStep() throws {
        var doc = try dashed(Self.plain)
        let before = doc.rects
        for i in 1...60 {
            _ = try catalog.run("stroke.trim", params: .object(["start": .number(0), "end": .number(1 - Double(i) / 120),
                                                               "drag": .string("rj-x35")]), on: &doc)
        }
        #expect(doc.history.steps == ["Add Stroke", "Stroke Width", "Stroke Dash", "Trim Path"])
        #expect(doc.rects.first?.stroke?.trim?.end == 0.5 && doc.rects.first?.stroke?.dash == [16, 8])
        _ = try catalog.run("edit.undo", params: .object([:]), on: &doc)
        #expect(doc.rects == before && doc.rects.first?.stroke?.trim == nil)
    }
}
