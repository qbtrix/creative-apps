// PhotoAreaSelectionTests.swift: MJ-AR-photo (area-selection AR-9 writes it, AR-10 turns it on). Photo's selection
// is SuiteKernel's area recipe rendered by SuiteImaging's AreaMask behind Photo's own API: every select.* area
// command runs through the catalog, Delete and Fill weight each pixel by the mask's coverage, Reselect brings back
// the area a Deselect dropped, Undo puts back the earlier area, and the mask is the canvas's size. RJ-X70
// (Tests/RealJobs/photo/select-shapes) runs here as the harness runs it. Runs on Linux and macOS.
import CoreRaster
import Foundation
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoAreaSelectionTests {
    static func run(_ id: String, _ params: [String: JSONValue] = [:], on workspace: inout PhotoWorkspace) throws {
        _ = try PhotoWorkspace.catalog.run(id, params: .object(params), on: &workspace)
    }
    static func box(_ minX: Double, _ minY: Double, _ maxX: Double, _ maxY: Double, mode: String? = nil) -> [String: JSONValue] {
        var params: [String: JSONValue] = ["minX": .number(minX), "minY": .number(minY), "maxX": .number(maxX), "maxY": .number(maxY)]
        params["mode"] = mode.map(JSONValue.string)
        return params
    }
    static func points(_ xy: [(Double, Double)], mode: String? = nil) -> [String: JSONValue] {
        var params: [String: JSONValue] = ["points": .array(xy.map { .object(["x": .number($0.0), "y": .number($0.1)]) })]
        params["mode"] = mode.map(JSONValue.string)
        return params
    }
    /// The selection's coverage at each of `at`.
    static func coverage(_ workspace: PhotoWorkspace, _ at: [(Int, Int)]) -> [Float] {
        at.map { workspace.selectionCoverage(x: $0.0, y: $0.1) }
    }
    static let probes = [(32, 12), (32, 30), (2, 2), (10, 32), (54, 32)]

    @Test func ellipseThenLassoSubtractLeavesTheHole() throws {
        var workspace = try PhotoGradientToolTests.gray()
        try Self.run("select.ellipse", Self.box(8, 8, 56, 56), on: &workspace)
        try Self.run("select.lasso", Self.points([(24, 24), (40, 24), (32, 40)], mode: "subtract"), on: &workspace)
        #expect(Self.coverage(workspace, [(32, 12), (32, 28), (2, 2)]) == [1, 0, 0])
        #expect(workspace.selection == PixelRect(x: 8, y: 8, width: 48, height: 48))
    }

    @Test func fillSelectionWeightsByTheFeatheredCoverage() throws {
        var workspace = try PhotoGradientToolTests.gray()
        try Self.run("select.rect", Self.box(16, 16, 48, 48), on: &workspace)
        try Self.run("select.feather", ["radius": .number(8)], on: &workspace)
        try Self.run("edit.fill-selection", on: &workspace)
        #expect(try PhotoGradientToolTests.red(workspace, 32, 32) == 0) // the brush's black, fully covered
        #expect(try PhotoGradientToolTests.red(workspace, 1, 1) == 128) // far outside, untouched
        let row = try (0..<32).map { try PhotoGradientToolTests.red(workspace, $0, 32) ?? 0 }
        #expect(row.filter { $0 > 13 && $0 < 115 }.count >= 6, "\(row)") // a soft edge, not a hard cut
    }

    @Test func reselectAfterDeselectRestoresTheArea() throws {
        var workspace = try PhotoGradientToolTests.gray()
        #expect(PhotoWorkspace.catalog.availability("select.reselect", on: workspace) != .available)
        try Self.run("select.ellipse", Self.box(8, 8, 56, 40), on: &workspace)
        try Self.run("select.lasso", Self.points([(24, 16), (40, 16), (32, 32)], mode: "subtract"), on: &workspace)
        let (bounds, seen) = (workspace.selection, Self.coverage(workspace, Self.probes))
        try Self.run("select.deselect", on: &workspace)
        #expect(workspace.selection == nil)
        try Self.run("select.reselect", on: &workspace)
        #expect(workspace.selection == bounds)
        #expect(Self.coverage(workspace, Self.probes) == seen)
    }

    @Test func undoPutsBackTheEarlierArea() throws {
        var workspace = try PhotoGradientToolTests.gray()
        try Self.run("select.rect", Self.box(4, 4, 20, 20), on: &workspace)
        try Self.run("select.ellipse", Self.box(30, 30, 60, 60, mode: "add"), on: &workspace)
        #expect(Self.coverage(workspace, [(10, 10), (45, 45)]) == [1, 1])
        workspace.undo()
        #expect(workspace.selection == PixelRect(x: 4, y: 4, width: 16, height: 16))
        #expect(Self.coverage(workspace, [(10, 10), (45, 45)]) == [1, 0])
        try Self.run("select.invert", on: &workspace) // the recipe went back too: invert the rectangle alone
        #expect(Self.coverage(workspace, [(10, 10), (45, 45)]) == [0, 1])
        workspace.undo()
        workspace.redo()
        #expect(Self.coverage(workspace, [(10, 10), (45, 45)]) == [0, 1])
    }

    @Test func theMaskIsTheCanvasSizeOnAWideImage() throws {
        var workspace = try PhotoGradientToolTests.gray(80, 40)
        try Self.run("select.ellipse", Self.box(0, 0, 80, 40), on: &workspace)
        #expect(workspace.selectionMask.map { [$0.width, $0.height] } == [80, 40])
        #expect(Self.coverage(workspace, [(40, 20), (70, 20), (79, 1)]) == [1, 1, 0])
        try Self.run("select.wand", ["x": .number(70), "y": .number(30), "tolerance": .number(0)], on: &workspace)
        #expect(workspace.selection == PixelRect(x: 0, y: 0, width: 80, height: 40)) // one grey: the whole wide canvas
    }

    @Test func everyOraFixtureOpensWithNothingSelected() throws {
        let tests = PhotoJob.root.deletingLastPathComponent().deletingLastPathComponent()
        let walker = FileManager.default.enumerator(atPath: tests.path)
        let files = (walker?.allObjects as? [String] ?? []).filter { $0.hasSuffix(".ora") && !$0.contains("/out/") }.sorted()
        #expect(!files.isEmpty)
        for file in files {
            let data = try Data(contentsOf: tests.appendingPathComponent(file))
            guard let doc = try? PhotoHeadless.open(data, name: file) else { continue } // a deliberately broken fixture
            #expect(doc.workspace.selection == nil && doc.workspace.selectionMask == nil, "\(file)")
            #expect(PhotoWorkspace.catalog.availability("select.invert", on: doc.workspace) != .available, "\(file)")
            let reopened = try PhotoHeadless.open(doc.save(), name: file)
            #expect(try reopened.workspace.snapshot() == doc.workspace.snapshot(), "\(file)")
        }
    }

    // MARK: RJ-X70

    @Test func selectShapesJobPasses() throws {
        #expect(try PhotoJob.check("select-shapes") == [])
        let folder = PhotoJob.root.appendingPathComponent("select-shapes")
        let script = try JSONDecoder().decode(PhotoJob.Script.self, from: Data(contentsOf: folder.appendingPathComponent("select-shapes.jobs.json")))
        let input = try Data(contentsOf: folder.appendingPathComponent("input/portrait.png"))
        var doc = try PhotoHeadless.open(input, name: "portrait.png")
        let report = PhotoHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
        #expect(report.stoppedAt == nil, "\(report.steps.compactMap(\.error))")
        let data = try #require(try doc.export(script.output.format, options: script.output.options).first?.data)
        let (before, after) = try (CoreRasterImageCodec.readPNG(input).rgba8(), CoreRasterImageCodec.readPNG(data).rgba8())
        func red(_ bytes: [UInt8], _ x: Int, _ y: Int) -> Int { bytes.indices.contains((y * 96 + x) * 4) ? Int(bytes[(y * 96 + x) * 4]) : -1 }
        #expect(red(after, 48, 40) == red(before, 48, 40)) // the face centre
        #expect([red(after, 2, 2), red(after, 93, 93)] == [0, 0] as [Int]) // the surround
        #expect(red(after, 48, 66) < red(before, 48, 66) / 3) // the chin notch, filled though the feather softens it
        let ramp = (0..<48).filter { x in
            let filled = 1 - Double(red(after, x, 42)) / Double(max(red(before, x, 42), 1))
            return filled > 0.1 && filled < 0.9
        }
        #expect(ramp.count >= 6, "\(ramp)")
    }
}
