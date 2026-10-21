// FakeCanvasPathTests.swift (pen-paths PN-1 written, PN-9 turns on): the fake app's paths save, lock and stay compatible.
import Foundation
import Testing
import SuiteKernel
@Suite struct FakeCanvasPathTests {
    static let draw = JSONValue.object(["contours": .array([.object(["closed": .bool(false), "anchors": .array([
        .object(["x": .number(10), "y": .number(10), "kind": .string("corner")]), .object(["x": .number(90), "y": .number(40), "kind": .string("corner")])])])])])
    @Test(.disabled("waits on PN-9")) func pathSurvivesSaveAndOpen() throws {
        var doc = FakeCanvasDocument.fixture
        _ = try FakeCanvasDocument.catalog.run("path.draw", params: Self.draw, on: &doc)
        #expect(try FakeCanvasDocument.open(doc.save(), name: "canvas.fake").save() == doc.save())
    }
    @Test(.disabled("waits on PN-9")) func lockedRefusesPath() {
        var doc = FakeCanvasDocument(rects: FakeCanvasDocument.fixture.rects, selection: 2)
        #expect(throws: CatalogError.self) { try FakeCanvasDocument.catalog.run("path.draw", params: Self.draw, on: &doc) }
    }
    @Test(.disabled("waits on PN-9")) func oldJSONUnchanged() throws {
        #expect(!String(decoding: try FakeCanvasDocument.fixture.save(), as: UTF8.self).contains("\"path\""))
    }
}
