// PhotoSeveralLayersTests.swift: Hide and Show, Opacity, Delete and Move on
// every picked layer, one undo step each (multi-layer-select PM-2, PM-5,
// PM-6). An eye or slider on an unpicked row acts on that row alone; Delete
// refuses to take every layer. Runs on Linux and macOS.
import CoreRaster
import Foundation
import SuiteKernel
import Testing
@testable import PhotoModel

/// Four layers (fourLayers) with Layer 1 and Layer 3 picked, Layer 3 the
/// primary. Picked on the kernel selection, so it holds before PM-4's Command-click.
private func onePlusThree() throws -> (PhotoWorkspace, one: PhotoLayer.ID, two: PhotoLayer.ID, three: PhotoLayer.ID) {
    var workspace = try fourLayers()
    let (one, two, three) = (layerID(workspace, "Layer 1"), layerID(workspace, "Layer 2"), layerID(workspace, "Layer 3"))
    workspace.layerSelection.replace([one, three])
    return (workspace, one, two, three)
}

private func layer(_ workspace: PhotoWorkspace, _ id: PhotoLayer.ID) -> PhotoLayer? {
    workspace.layers.first { $0.id == id }
}

@Suite struct PhotoSeveralLayersTests {
    @Test func anEyeOnAPickedRowHidesEveryPickedLayer() throws {
        var (workspace, one, two, three) = try onePlusThree()
        workspace.toggleVisibility(one)
        #expect(layer(workspace, one)?.isVisible == false && layer(workspace, three)?.isVisible == false)
        #expect(layer(workspace, two)?.isVisible == true)
        #expect(workspace.undoActionName == "Undo Hide Layers")
    }

    @Test func anEyeOnAnUnpickedRowHidesOnlyThatLayer() throws {
        var (workspace, one, two, three) = try onePlusThree()
        workspace.toggleVisibility(two)
        #expect(layer(workspace, two)?.isVisible == false)
        #expect(layer(workspace, one)?.isVisible == true && layer(workspace, three)?.isVisible == true)
        #expect(workspace.undoActionName == "Undo Hide Layer")
    }

    @Test func opacityAppliesToEvery() throws {
        var (workspace, one, two, three) = try onePlusThree()
        let before = workspace.layers
        workspace.setOpacity(three, percent: 50)
        #expect(layer(workspace, one)?.opacity == 0.5 && layer(workspace, three)?.opacity == 0.5)
        #expect(layer(workspace, two)?.opacity == 1)
        workspace.setOpacity(three, percent: 40)
        workspace.setOpacity(three, percent: 30)
        workspace.undo()
        #expect(workspace.layers == before)
    }

    @Test func deleteRefusesAll() throws {
        var workspace = try fourLayers()
        #expect(workspace.removeSelectedHelp == nil)
        workspace.selectAllLayers()
        #expect(workspace.removeSelectedHelp == "At least one layer must stay.")
        let before = workspace.layers
        workspace.removeSelectedLayers()
        #expect(workspace.layers == before)
    }

    @Test func threePickedDeleteInOneStepAndUndoKeepsTheOrder() throws {
        var (workspace, one, two, three) = try onePlusThree()
        let before = workspace.layers.map(\.id)
        workspace.layerSelection.replace([one, two, three])
        workspace.removeSelectedLayers()
        #expect(workspace.layers.map(\.name) == ["Background"])
        #expect(workspace.undoActionName == "Undo Delete Layers")
        workspace.undo()
        #expect(workspace.layers.map(\.id) == before)
    }

    @Test func oneStepForSeveral() throws {
        var (workspace, one, _, _) = try onePlusThree()
        let (before, undoName) = (workspace.layers, workspace.undoActionName)
        workspace.toggleVisibility(one)
        workspace.undo()
        #expect(workspace.layers == before)
        #expect(workspace.undoActionName == undoName)
    }

    @Test func anEyeOnAHiddenPickedRowShowsEveryPickedLayer() throws {
        var (workspace, one, _, three) = try onePlusThree()
        workspace.toggleVisibility(three)
        workspace.toggleVisibility(three)
        #expect(layer(workspace, one)?.isVisible == true && layer(workspace, three)?.isVisible == true)
        #expect(workspace.undoActionName == "Undo Show Layers")
    }

    @Test func commandsPickAndSetOpacity() throws {
        var (workspace, one, two, three) = try onePlusThree()
        let catalog = PhotoWorkspace.catalog
        _ = try catalog.run("layer.set-opacity", params: .object(["percent": .number(25)]), on: &workspace)
        #expect(layer(workspace, one)?.opacity == 0.25 && layer(workspace, three)?.opacity == 0.25)
        #expect(layer(workspace, two)?.opacity == 1)
        _ = try catalog.run("layer.select-all", params: .object([:]), on: &workspace)
        #expect(workspace.selectedLayerIDs.count == 4)
        _ = try catalog.run("layer.pick", params: .object(["id": .string(two), "mode": .string("replace")]), on: &workspace)
        #expect(workspace.selectedLayerIDs == [two])
        #expect(throws: (any Error).self) {
            try catalog.run("layer.pick", params: .object(["id": .string("layer-99"), "mode": .string("replace")]), on: &workspace)
        }
    }

    @Test func moveMovesEvery() throws {
        var (workspace, one, two, three) = try onePlusThree()
        stroke(&workspace, .move, from: point(2, 2), to: point(5, 3))
        #expect(layer(workspace, one)?.offsetX == 3 && layer(workspace, one)?.offsetY == 1)
        #expect(layer(workspace, three)?.offsetX == 3 && layer(workspace, three)?.offsetY == 1)
        #expect(layer(workspace, two)?.offsetX == 0)
        #expect(workspace.undoActionName == "Undo Move Layers")
        workspace.moveSelectedLayers(dx: -1, dy: 2)
        #expect(layer(workspace, one)?.offsetX == 2 && layer(workspace, three)?.offsetY == 3)
        workspace.undo()
        workspace.undo()
        #expect(layer(workspace, one)?.offsetX == 0 && layer(workspace, three)?.offsetX == 0)
    }

    @Test func moveOneStep() throws {
        var (workspace, one, _, three) = try onePlusThree()
        let (before, undoName) = (workspace.layers, workspace.undoActionName)
        workspace.selectTool(.move)
        for x in [2.0, 3, 4, 6] { workspace.drag(from: point(2, 2), to: point(x, 2)) }
        workspace.endDrag()
        #expect(layer(workspace, one)?.offsetX == 4 && layer(workspace, three)?.offsetX == 4)
        #expect(workspace.undoActionName == "Undo Move Layers")
        workspace.undo()
        #expect(workspace.layers == before)
        #expect(workspace.undoActionName == undoName)
    }

    @Test func oneLayerMovesAsBefore() throws {
        var (workspace, one, _, three) = try onePlusThree()
        workspace.selectedLayerID = one
        stroke(&workspace, .move, from: point(2, 2), to: point(4, 2))
        #expect(layer(workspace, one)?.offsetX == 2 && layer(workspace, three)?.offsetX == 0)
        #expect(workspace.undoActionName == "Undo Move Layer")
    }

    @Test func moveByCommandMovesEveryInOneStep() throws {
        var (workspace, one, two, three) = try onePlusThree()
        let before = workspace.layers
        _ = try PhotoWorkspace.catalog.run(
            "layer.move-by", params: .object(["dx": .number(40), "dy": .number(-3)]), on: &workspace)
        #expect(layer(workspace, one)?.offsetX == 40 && layer(workspace, three)?.offsetY == -3)
        #expect(layer(workspace, two)?.offsetX == 0)
        #expect(workspace.undoActionName == "Undo Move Layers")
        workspace.undo()
        #expect(workspace.layers == before)
    }

    @Test func anAdjustmentLayerAmongThePickedStaysPut() throws {
        var (workspace, one, _, three) = try onePlusThree()
        workspace.addAdjustmentLayer(.exposure)
        let adjustment = try #require(workspace.selectedLayerID)
        workspace.layerSelection.replace([adjustment, three, one])
        workspace.moveSelectedLayers(dx: 2, dy: 0)
        #expect(layer(workspace, one)?.offsetX == 2 && layer(workspace, three)?.offsetX == 2)
        #expect(layer(workspace, adjustment)?.offsetX == 0)
    }

    /// Packet budget row (stress gate): one Move step with 100 layers picked,
    /// <= 8 ms on Linux. Kept out of the merge gate until the supervisor lists
    /// it in Tests/perf-suites.txt.
    @Test(.disabled("perf: waits on a Tests/perf-suites.txt line")) func moveHundredInBudget() throws {
        var workspace = try whiteImage(8, 8)
        for _ in 0..<99 { workspace.addLayer() }
        workspace.selectAllLayers()
        let clock = ContinuousClock(), started = clock.now
        stroke(&workspace, .move, from: point(0, 0), to: point(5, 5))
        #expect(clock.now - started <= .milliseconds(8))
        #expect(workspace.layers.allSatisfy { $0.offsetX == 5 })
    }

    /// RJ-P43, run here on PhotoHeadless since the CLI's harness can't decode
    /// its pixels yet. Its Shift-picks need PM-4's `pickLayer` (#4095).
    @Test(.disabled("RJ-P43 waits on PM-4's Shift-click extend (#4095)")) func fadeLayersRealJob() throws {
        struct Script: Decodable { var steps: [CommandEnvelope]; var atomic: Bool }
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RealJobs/photo/fade-layers")
        let file = { (path: String) in try Data(contentsOf: folder.appendingPathComponent(path)) }
        let script = try JSONDecoder().decode(Script.self, from: file("fade-layers.jobs.json"))
        var doc = try PhotoHeadless.open(file("input/four-layers.ora"), name: "four-layers.ora")
        let report = PhotoHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
        #expect(report.stoppedAt == nil, "\(report.steps.compactMap(\.error))")
        #expect(doc.workspace.undoActionName == "Undo Move Layers")
        let exported = try #require(doc.export("png", options: .object([:])).first)
        let got = try PhotoHeadless.codec.decode(exported.data, longestSide: nil)
        let want = try PhotoHeadless.codec.decode(file("expected/four-layers-faded.png"), longestSide: nil)
        #expect(got.width == want.width && got.height == want.height)
        #expect(got.rgba8.count == want.rgba8.count
            && zip(got.rgba8, want.rgba8).allSatisfy { abs(Int($0) - Int($1)) <= 2 }, "the export matches within 2")
    }

    @Test func moveSelectedLayersMovesThePrimaryInOneStep() throws {
        var workspace = try fourLayers()
        let top = try #require(workspace.selectedLayerID)
        workspace.moveSelectedLayers(dx: 4, dy: -2)
        #expect(layer(workspace, top)?.offsetX == 4 && layer(workspace, top)?.offsetY == -2)
        workspace.undo()
        #expect(layer(workspace, top)?.offsetX == 0 && layer(workspace, top)?.offsetY == 0)
    }
}
