// SampleCommandsTests.swift (eyedropper EY-1 written, EY-6 turns on): `color.sample` on a test target that paints
// one colour per sample size over a 100 × 100 document. The spec shape check runs now; the runs are disabled by name
// until EY-6 builds the body.
import Testing
import SuiteKernel

/// A document whose every point inside 0..<100 reads `colors[size]`; outside it, or for a size it lacks, nothing.
struct SampleDoc: SampleTarget {
    var colors: [SampleSize: FillColor] = [.point: FillColor(r: 1, g: 0, b: 0)]
    var sampleHelp: String?
    func sampledColor(at point: Point, size: SampleSize) -> FillColor? {
        (0..<100).contains(point.x) && (0..<100).contains(point.y) ? colors[size] : nil
    }
}

@Suite struct SampleCommandsTests {
    static let catalog = try? CommandCatalog(app: "test", SampleCommands.specs(SampleDoc.self), history: { _ in History<Int>() })
    static func at(_ x: Double, _ y: Double, size: Int? = nil) -> JSONValue {
        .object(["x": .number(x), "y": .number(y)].merging(size.map { ["size": .number(Double($0))] } ?? [:]) { old, _ in old })
    }

    @Test func specIsOneQuery() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == ["color.sample"])
        let spec = try #require(catalog.spec("color.sample"))
        #expect(spec.kind == .query && !spec.undoable)
        #expect(spec.params.validate(Self.at(10, 20, size: 3)).isEmpty)
        #expect(!spec.params.validate(.object(["x": .number(1)])).isEmpty)
        #expect(catalog.availability("color.sample", on: SampleDoc()) == .available)
        #expect(catalog.availability("color.sample", on: SampleDoc(sampleHelp: "Open an image first.")) == .unavailable("Open an image first."))
    }
    @Test(.disabled("waits on EY-6")) func readsHexAndChannels() throws {
        let catalog = try #require(Self.catalog)
        var doc = SampleDoc()
        let outcome = try catalog.run("color.sample", params: Self.at(10, 10), on: &doc)
        let color: JSONValue = .object(["hex": .string("#FF0000"), "r": .number(255), "g": .number(0), "b": .number(0), "a": .number(255)])
        #expect(outcome.result == .object(["color": color]))
        #expect(outcome.undoStep == nil)
    }
    @Test(.disabled("waits on EY-6")) func emptySpaceIsNull() throws {
        let catalog = try #require(Self.catalog)
        var doc = SampleDoc()
        #expect(try catalog.run("color.sample", params: Self.at(500, 500), on: &doc).result == .object(["color": .null]))
    }
    @Test(.disabled("waits on EY-6")) func passesSize() throws {
        let catalog = try #require(Self.catalog)
        var doc = SampleDoc(colors: [.point: FillColor(r: 1, g: 0, b: 0), .fiveByFive: FillColor(r: 0, g: 0, b: 1)])
        let result = try catalog.run("color.sample", params: Self.at(10, 10, size: 5), on: &doc).result
        guard case .object(let fields) = result, case .object(let color)? = fields["color"] else {
            Issue.record("no colour in \(result)"); return
        }
        #expect(color["hex"] == .string("#0000FF"))
    }
    @Test(.disabled("waits on EY-6")) func honoursSampleHelp() throws {
        let catalog = try #require(Self.catalog)
        var doc = SampleDoc(sampleHelp: "Open an image first.")
        #expect(throws: CatalogError.unavailable(id: "color.sample", why: "Open an image first.")) { try catalog.run("color.sample", params: Self.at(10, 10), on: &doc) }
    }
}
