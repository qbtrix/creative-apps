// PhotoRetouchKernelTests.swift (fill-heal FH-7): Photo's workspace as
// SuiteImaging's RetouchTarget. fill.bucket, retouch.spot-heal, retouch.heal
// (the Heal tool's stroke) and retouch.remove each edit only the selected
// pixel layer, as one undo step that undo takes back byte for byte; the
// bucket keeps inside the selection; heal waits for an Option-click; a
// layer with no pixels to edit refuses with its reason. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoRetouchKernelTests {
    /// A white background under a half-opaque gray layer (selected) with a
    /// black dot at (32, 32), so the composite differs from the layer.
    private func dotted() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        addFilledLayer(&workspace, red: 128, green: 128, blue: 128)
        _ = try PhotoWorkspace.catalog.run("layer.set-opacity", params: .object(["percent": .number(50)]), on: &workspace)
        workspace.setToolOption(.color(red: 0, green: 0, blue: 0))
        workspace.setToolOption(.size(6))
        stroke(&workspace, .brush, from: point(32, 32), to: point(32, 32))
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        return workspace
    }

    private func run(_ id: String, _ params: [String: JSONValue], on workspace: inout PhotoWorkspace) throws {
        _ = try PhotoWorkspace.catalog.run(id, params: .object(params), on: &workspace)
    }

    private static func xy(_ x: Double, _ y: Double) -> JSONValue { .object(["x": .number(x), "y": .number(y)]) }

    /// Edit `index` on `dotted()`: its undo name, and a pixel of the layer it must leave alone.
    private static func edit(_ index: Int, _ w: inout PhotoWorkspace) throws -> (name: String, untouched: (x: Int, y: Int)) {
        switch index {
        case 0:
            _ = try PhotoWorkspace.catalog.run("fill.bucket", params: .object(["x": .number(4), "y": .number(4)]), on: &w)
            return ("Paint Bucket", (32, 32))
        case 1:
            _ = try PhotoWorkspace.catalog.run(
                "retouch.spot-heal", params: .object(["x": .number(32), "y": .number(32), "size": .number(12)]), on: &w)
            return ("Spot Heal", (2, 2))
        case 2:
            w.selectTool(.heal)
            w.setToolOption(.size(8))
            w.drag(from: point(12, 12), to: point(12, 12), modifiers: [.option])
            w.endDrag()
            w.drag(from: point(32, 32), to: point(32, 32))
            w.drag(from: point(32, 32), to: point(34, 32))
            w.endDrag()
            return ("Heal", (2, 2))
        default:
            _ = try PhotoWorkspace.catalog.run(
                "retouch.remove", params: .object(["points": .array([xy(31, 32), xy(33, 32)]), "size": .number(10)]), on: &w)
            return ("Remove", (2, 2))
        }
    }

    // Case 2, the Heal tool's stroke, joins once its release runs retouch.heal (FH-7, part 2).
    @Test(arguments: [0, 1, 3])
    func editsSelectedLayer(_ index: Int) throws {
        var workspace = try dotted()
        let layerID = try #require(workspace.selectedLayerID)
        let backgroundID = try #require(workspace.layers.first { $0.id != layerID }?.id)
        let before = workspace.pixels, steps = workspace.historySteps.count
        let (name, untouched) = try Self.edit(index, &workspace)
        #expect(workspace.pixels[layerID] != before[layerID], "\(name) changed the layer")
        #expect(workspace.pixels[backgroundID] == before[backgroundID], "\(name) left the background alone")
        #expect(try workspace.pixels[layerID]?.pixel(x: untouched.x, y: untouched.y)
                == before[layerID]?.pixel(x: untouched.x, y: untouched.y), "\(name) edited only where it acts")
        #expect(workspace.historySteps.count == steps + 1, "\(name) is one undo step")
        #expect(workspace.undoActionName == "Undo \(name)")
        workspace.undo()
        #expect(workspace.pixels == before, "undo restores \(name) byte for byte")
    }

    @Test func theBucketKeepsInsideTheSelection() throws {
        var workspace = try dotted()
        try run("select.rect", ["minX": .number(8), "minY": .number(8), "maxX": .number(24), "maxY": .number(24)], on: &workspace)
        let before = try #require(workspace.selectedLayerID.flatMap { workspace.pixels[$0] })
        try run("fill.bucket", ["x": .number(10), "y": .number(10)], on: &workspace)
        let after = try #require(workspace.selectedLayerID.flatMap { workspace.pixels[$0] })
        #expect(try after.pixel(x: 12, y: 12) != before.pixel(x: 12, y: 12))
        #expect(try after.pixel(x: 4, y: 4) == before.pixel(x: 4, y: 4))
        #expect(try after.pixel(x: 40, y: 40) == before.pixel(x: 40, y: 40))
    }

    @Test func selectionCoverageOnly() throws {
        var workspace = try dotted()
        #expect(workspace.selectionCoverage == nil)
        #expect(PhotoWorkspace.catalog.availability("retouch.remove", on: workspace) == .available)
        #expect(throws: CatalogError.self) { try run("retouch.remove", [:], on: &workspace) }
        try run("select.rect", ["minX": .number(28), "minY": .number(28), "maxX": .number(36), "maxY": .number(36)], on: &workspace)
        let mask = try #require(workspace.selectionCoverage)
        #expect(try mask.coverage(x: 30, y: 30) == 1 && mask.coverage(x: 4, y: 4) == 0)
        workspace.deselect()
        #expect(workspace.selectionCoverage == nil)
    }

    @Test func healWaitsForAnOptionClick() throws {
        var workspace = try dotted()
        #expect(PhotoWorkspace.catalog.availability("retouch.heal", on: workspace) == .unavailable("Option-click a source first."))
        workspace.selectTool(.heal)
        workspace.drag(from: point(12, 12), to: point(12, 12), modifiers: [.option])
        workspace.endDrag()
        workspace.drag(from: point(32, 32), to: point(33, 32))
        workspace.endDrag()
        #expect(workspace.cloneOffset?.dx == -20 && workspace.cloneOffset?.dy == -20)
        #expect(PhotoWorkspace.catalog.availability("retouch.heal", on: workspace) == .available)
    }

    @Test func aLayerWithNoPixelsToEditRefusesWithItsReason() throws {
        #expect(PhotoWorkspace().retouchHelp == "Open an image first.")
        var adjusted = try dotted()
        adjusted.addAdjustmentLayer(.exposure)
        #expect(adjusted.targetPixels == nil)
        let why = try #require(adjusted.retouchHelp)
        for id in ["fill.bucket", "retouch.spot-heal", "retouch.remove"] {
            #expect(PhotoWorkspace.catalog.availability(id, on: adjusted) == .unavailable(why), "\(id)")
        }
        var text = try dotted()
        try run("text.add", ["x": .number(4), "y": .number(4), "words": .string("Hi")], on: &text)
        let locked = try #require(text.retouchHelp)
        #expect(locked != why)
        #expect(PhotoWorkspace.catalog.availability("fill.bucket", on: text) == .unavailable(locked))
    }

    @Test func theTargetIsTheSelectedLayerOnTheCanvas() throws {
        let workspace = try dotted()
        let target = try #require(workspace.targetPixels)
        let layer = try #require(workspace.selectedLayerID.flatMap { workspace.pixels[$0] })
        #expect(target == (try layer.flattened()))
        #expect(workspace.mergedPixels == (try workspace.composite()))
        let paint = workspace.paintColor
        #expect(abs(paint.r - 1) < 1e-4 && paint.g == 0 && paint.b == 0 && paint.a == 1)
    }

    @Test(arguments: ["bucket-background"])
    func realJobPasses(job: String) throws {
        #expect(try PhotoJob.check(job) == [], "\(job)")
    }
}
