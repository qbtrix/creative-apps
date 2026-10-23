// FakeTransformTests.swift (transform-tools TT-8): the fake app turns and flips. A turn and its mirrors survive save
// and open, a locked rect refuses with its reason, a rect at no turn saves the JSON it always did, and RJ-X32's
// 60-sample drag is one undo step whose flip keeps the rect where it was.
import Foundation
import Testing
import SuiteKernel

@Suite struct FakeTransformTests {
    let catalog = FakeCanvasDocument.catalog
    /// One free rect, selected, as RJ-X32's `one.fake` reads after `rect.select`.
    static let one = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 10, y: 10, w: 100, h: 60)], selection: 1)
    static let old = #"[{"h":60,"id":1,"locked":false,"name":"Rect 1","w":100,"x":10,"y":10}]"#

    @Test func theFakeListsTheTransformCommands() {
        let transform = TransformCommands.specs(FakeCanvasDocument.self).map(\.id)
        #expect(transform.count == 6 && transform.allSatisfy(catalog.ids.contains))
        #expect(Self.one.transformSelection == TransformBox(box: Rect(minX: 10, minY: 10, maxX: 110, maxY: 70)))
        #expect(FakeCanvasDocument().transformSelection == nil && FakeCanvasDocument().transformHelp == "Select a rectangle first.")
    }

    @Test func aTurnAndFlipsSurviveSaveAndOpen() throws {
        var doc = Self.one
        _ = try catalog.run("transform.rotate", params: .object(["degrees": .number(30)]), on: &doc)
        _ = try catalog.run("transform.flip", params: .object(["axis": .string("horizontal")]), on: &doc)
        _ = try catalog.run("transform.flip", params: .object(["axis": .string("vertical")]), on: &doc)
        #expect(doc.rects.first.map { ($0.degrees, $0.flipX, $0.flipY, $0.x, $0.y) } ?? (0, false, false, 0, 0) == (30, true, true, 10, 10))
        let opened = try FakeCanvasDocument.open(doc.save(), name: "canvas.fake")
        #expect(opened.rects == doc.rects)
        #expect(try opened.save() == doc.save())
        let read = try catalog.run("transform.read", params: .object([:]), on: &doc)
        #expect(read.result == .object(["x": .number(10), "y": .number(10), "w": .number(100), "h": .number(60),
                                        "degrees": .number(30), "flipX": .bool(true), "flipY": .bool(true)]))
    }

    @Test func lockedRefusesTurn() {
        var doc = FakeCanvasDocument(rects: FakeCanvasDocument.fixture.rects, selection: 2)
        #expect(catalog.availability("transform.rotate", on: doc) == .unavailable("Unlock Rect 2 first."))
        #expect(catalog.availability("transform.flip", on: doc) == .unavailable("Unlock Rect 2 first."))
        // setTransform refuses on its own too, not only through the catalog's availability check.
        let turned = TransformBox(box: Rect(minX: 140, minY: 40, maxX: 220, maxY: 120), degrees: 45)
        #expect(throws: CatalogError.unavailable(id: "transform", why: "Unlock Rect 2 first.")) {
            try doc.setTransform(turned, name: "Rotate", drag: nil)
        }
        #expect(doc.rects == FakeCanvasDocument.fixture.rects && doc.history.steps.isEmpty)
    }

    @Test func oldJSONUnchanged() throws {
        #expect(String(decoding: try Self.one.save(), as: UTF8.self) == Self.old)
        let opened = try FakeCanvasDocument.open(Data(Self.old.utf8), name: "one.fake")
        #expect(opened.rects == Self.one.rects && opened.rects.first.map { ($0.degrees, $0.flipX, $0.flipY) } ?? (1, true, true) == (0, false, false))
        // Turned and mirrored, then reset: the rect saves its old bytes again.
        var doc = Self.one
        _ = try catalog.run("transform.rotate", params: .object(["degrees": .number(15)]), on: &doc)
        _ = try catalog.run("transform.flip", params: .object(["axis": .string("vertical")]), on: &doc)
        #expect(String(decoding: try doc.save(), as: UTF8.self) != Self.old)
        _ = try catalog.run("transform.reset", params: .object([:]), on: &doc)
        #expect(String(decoding: try doc.save(), as: UTF8.self) == Self.old)
    }

    /// RJ-X32 in process: 60 quarter-degree samples under one drag token, a flip, then undo twice.
    @Test func aSixtySampleTurnIsOneUndoStepAndTheFlipKeepsThePlace() throws {
        var doc = Self.one
        for _ in 1...60 {
            _ = try catalog.run("transform.rotate", params: .object(["degrees": .number(0.25), "drag": .string("rj-x32")]), on: &doc)
        }
        #expect(doc.history.steps == ["Rotate"] && doc.rects.first?.degrees == 15)
        let flip = try catalog.run("transform.flip", params: .object(["axis": .string("horizontal")]), on: &doc)
        #expect(flip.undoStep == "Flip Horizontal" && doc.rects.first.map { ($0.degrees, $0.flipX, $0.x, $0.y) } ?? (0, false, 0, 0) == (-15, true, 10, 10))
        #expect(doc.step(redo: false) && doc.rects.first.map { ($0.degrees, $0.flipX, $0.x, $0.y) } ?? (0, true, 0, 0) == (15, false, 10, 10))
        #expect(doc.step(redo: false) && doc.rects == Self.one.rects && !doc.history.canUndo)
    }
}
