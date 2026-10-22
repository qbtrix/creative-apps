// FakeSampleTests.swift (eyedropper EY-8): the fake canvas is an eyedropper target. The topmost rect under the point
// wins whatever is selected, a gradient reads its colour at the point (not its first stop), a turned rect reads in
// its own frame, empty canvas reads nil, and RJ-X33's steps return the samples its job file lists.
import Foundation
import Testing
import SuiteKernel

@Suite struct FakeSampleTests {
    let catalog = FakeCanvasDocument.catalog
    static let blue = FillColor(r: 0, g: 0, b: 1), red = FillColor(r: 1, g: 0, b: 0)
    /// Blue to white, left to right across a 100 × 60 box.
    static let blueToWhite = Fill.linear(stops: [GradientStop(offset: 0, color: blue), GradientStop(offset: 1, color: .white)],
                                         start: Point(x: 0, y: 30), end: Point(x: 100, y: 30))
    /// RJ-X33's canvas: the gradient (selected) under a red rect that overlaps its right end.
    static let twoFills = FakeCanvasDocument(rects: [
        FakeRect(id: 1, name: "Rect 1", x: 10, y: 10, w: 100, h: 60, fill: blueToWhite),
        FakeRect(id: 2, name: "Rect 2", x: 80, y: 20, w: 60, h: 40, fill: .solid(red)),
    ], selection: 1)

    @Test func theFakeListsColorSample() {
        #expect(catalog.ids.contains("color.sample"))
        #expect(Self.twoFills.sampleHelp == nil)
        #expect(catalog.availability("color.sample", on: Self.twoFills) == .available)
    }

    @Test func theTopmostRectWinsOverTheSelectedOne() {
        #expect(Self.twoFills.sampledColor(at: Point(x: 90, y: 40), size: .point) == Self.red)
        // Only the lower rect under the point: its gradient, 80% of the way to white.
        let low = Self.twoFills.sampledColor(at: Point(x: 70, y: 15), size: .point)
        #expect(low.map { [$0.r, $0.g, $0.b, $0.a] } == [0.6, 0.6, 1, 1])
    }

    @Test func aGradientReadsItsColourAtThePoint() {
        #expect(Self.twoFills.sampledColor(at: Point(x: 60, y: 40), size: .point) == FillColor(r: 0.5, g: 0.5, b: 1))
        #expect(Self.twoFills.sampledColor(at: Point(x: 10, y: 40), size: .point) == Self.blue)
    }

    @Test func aRadialReadsOutFromItsCentre() {
        let radial = Fill.radial(stops: [GradientStop(offset: 0, color: .white), GradientStop(offset: 1, color: .black)],
                                 center: Point(x: 50, y: 50), radius: 50)
        let doc = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 0, y: 0, w: 100, h: 100, fill: radial)])
        #expect(doc.sampledColor(at: Point(x: 75, y: 50), size: .point) == FillColor(r: 0.5, g: 0.5, b: 0.5))
        #expect(doc.sampledColor(at: Point(x: 0, y: 0), size: .point) == .black)
    }

    @Test func aTurnedRectReadsInItsOwnFrame() throws {
        var rect = FakeRect(id: 1, name: "Rect 1", x: 0, y: 0, w: 100, h: 60, fill: Self.blueToWhite)
        rect.degrees = 180
        let doc = FakeCanvasDocument(rects: [rect])
        // Turned half a turn, the blue end sits on the right.
        let right = try #require(doc.sampledColor(at: Point(x: 95, y: 30), size: .point))
        #expect(abs(right.r - 0.05) < 1e-9 && right.b == 1)
    }

    @Test func emptyCanvasAndAnUnfilledRectRead() {
        #expect(Self.twoFills.sampledColor(at: Point(x: 200, y: 200), size: .point) == nil)
        #expect(Self.twoFills.sampledColor(at: Point(x: 5, y: 5), size: .fiveByFive) == nil)
        #expect(FakeCanvasDocument().sampledColor(at: Point(x: 0, y: 0), size: .point) == nil)
        #expect(Self.twoFills.sampledColor(at: Point(x: .nan, y: 40), size: .point) == nil)
        let plain = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 0, y: 0, w: 10, h: 10)])
        #expect(plain.sampledColor(at: Point(x: 5, y: 5), size: .point) == .black)
    }

    /// RJ-X33: the job's steps, run through the catalog on its input, return its `samples` in order and change nothing.
    @Test func realJobX33ReadsItsSamples() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RealJobs/fake/sample-color")
        guard case .object(let job) = try JSONValue(json: Data(contentsOf: folder.appendingPathComponent("sample-color.jobs.json"))),
              case .array(let steps)? = job["steps"], case .array(let samples)? = job["samples"] else {
            Issue.record("sample-color.jobs.json has no steps and samples"); return
        }
        let input = try Data(contentsOf: folder.appendingPathComponent("input/two-fills.fake"))
        var doc = try FakeCanvasDocument.open(input, name: "two-fills.fake")
        #expect(doc.rects == Self.twoFills.rects)
        var read: [JSONValue] = []
        for case .object(let step) in steps {
            guard case .string(let id)? = step["id"] else { continue }
            let outcome = try catalog.run(id, params: step["params"] ?? .object([:]), on: &doc)
            if id == "color.sample" { read.append(outcome.result) }
        }
        #expect(read == samples)
        #expect(doc.rects == Self.twoFills.rects && doc.history.steps.isEmpty)
    }
}
