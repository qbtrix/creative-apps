// PhotoAreaToolTests.swift (area-selection AR-11): the area tools' drags (PhotoAreaTool.swift). Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoAreaToolTests {
    /// A white 64×64 image with `tool` picked.
    func canvas(_ tool: PhotoTool) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 64, height: 64)
        workspace.selectTool(tool)
        return workspace
    }

    /// Press at the first point, move through the rest, lift.
    func drag(_ workspace: inout PhotoWorkspace, _ points: [(Double, Double)], keys: DragModifiers = [], zoom: Double = 1) {
        let at = points.map { Mask.Point(x: $0.0, y: $0.1) }
        guard let start = at.first else { return }
        for end in at.dropFirst() { workspace.drag(from: start, to: end, modifiers: keys, zoom: zoom) }
        if at.count == 1 { workspace.drag(from: start, to: start, modifiers: keys, zoom: zoom) }
        workspace.endDrag()
    }

    @Test func theEllipseSelectsTheEllipseInItsDragAsOneUndoStep() throws {
        var workspace = try canvas(.ellipse)
        let steps = workspace.historySteps.count
        drag(&workspace, [(10, 10), (10.5, 30)])
        #expect(workspace.selection == nil && workspace.historySteps.count == steps, "a click selects nothing")
        drag(&workspace, [(10, 10), (30, 20), (50, 40)])
        #expect(workspace.areaRecipe.steps == [.shape(.ellipse(Rect(minX: 10, minY: 10, maxX: 50, maxY: 40)), .replace)])
        #expect(workspace.selectionCoverage(x: 30, y: 25) > 0.9)
        #expect(workspace.selectionCoverage(x: 11, y: 11) == 0)
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo Ellipse Select")
        workspace.undo()
        #expect(workspace.selection == nil && workspace.areaRecipe.isEmpty)
    }

    @Test func heldKeysPickTheModeOverTheOptions() throws {
        var workspace = try canvas(.marquee)
        drag(&workspace, [(0, 0), (40, 40)])
        #expect(workspace.areaRecipe.steps.count == 1)
        workspace.selectTool(.ellipse)
        drag(&workspace, [(20, 20), (60, 60)], keys: [.option])
        #expect(workspace.areaRecipe.steps.last == .shape(.ellipse(Rect(minX: 20, minY: 20, maxX: 60, maxY: 60)), .subtract))
        drag(&workspace, [(0, 0), (30, 30)], keys: [.shift, .option])
        #expect(workspace.areaRecipe.steps.last == .shape(.ellipse(Rect(minX: 0, minY: 0, maxX: 30, maxY: 30)), .intersect))
        workspace.setAreaOptions(PhotoAreaOptions(mode: .add))
        drag(&workspace, [(2, 2), (8, 8)])
        #expect(workspace.areaRecipe.steps.last == .shape(.ellipse(Rect(minX: 2, minY: 2, maxX: 8, maxY: 8)), .add))
        #expect(workspace.areaRecipe.steps.count == 4)
    }

    @Test func theMarqueeJoinsOnReleaseWithAKeyHeldAndStaysLiveWithout() throws {
        var workspace = try canvas(.marquee)
        drag(&workspace, [(0, 0), (20, 20)])
        let steps = workspace.historySteps.count
        workspace.drag(from: Mask.Point(x: 30, y: 30), to: Mask.Point(x: 50, y: 50), modifiers: [.shift])
        #expect(workspace.selection == PixelRect(x: 0, y: 0, width: 20, height: 20), "a joining drag leaves the selection until its release")
        #expect(workspace.areaDraft.count == 5)
        workspace.endDrag()
        #expect(workspace.areaRecipe.steps == [
            .shape(.rect(Rect(minX: 0, minY: 0, maxX: 20, maxY: 20)), .replace),
            .shape(.rect(Rect(minX: 30, minY: 30, maxX: 50, maxY: 50)), .add),
        ])
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo Rectangle Select")
    }

    @Test func eachShapeTakesTheOptionsFeather() throws {
        var workspace = try canvas(.marquee)
        workspace.setAreaOptions(PhotoAreaOptions(feather: 8))
        drag(&workspace, [(10, 10), (50, 50)])
        #expect(workspace.areaRecipe.steps == [.shape(.rect(Rect(minX: 10, minY: 10, maxX: 50, maxY: 50)), .replace), .feather(8)])
        #expect(workspace.undoActionName == "Undo Rectangle Select")
        let edge = workspace.selectionCoverage(x: 10, y: 30)
        #expect(edge > 0 && edge < 1)
    }

    @Test func theOptionsStayInTheirRanges() throws {
        var workspace = try canvas(.wand)
        workspace.setAreaOptions(PhotoAreaOptions(feather: 900, tolerance: -3))
        #expect(workspace.areaOptions.feather == 250 && workspace.areaOptions.tolerance == 0)
        workspace.setAreaOptions(PhotoAreaOptions(feather: .nan, tolerance: .infinity))
        #expect(workspace.areaOptions.feather == 0 && workspace.areaOptions.tolerance == 0)
    }

    @Test func theLassoSelectsInsideItsPathAndShowsItWhileItDrags() throws {
        var workspace = try canvas(.lasso)
        let start = Mask.Point(x: 10, y: 10)
        workspace.drag(from: start, to: Mask.Point(x: 50, y: 10), modifiers: [])
        workspace.drag(from: start, to: Mask.Point(x: 50, y: 50), modifiers: [])
        #expect(workspace.areaDraft == [Point(x: 10, y: 10), Point(x: 50, y: 10), Point(x: 50, y: 50)])
        workspace.endDrag()
        #expect(workspace.areaDraft.isEmpty)
        guard case .shape(.lasso(let points), .replace)? = workspace.areaRecipe.steps.first else {
            Issue.record("no lasso step"); return
        }
        #expect(points.first == Point(x: 10, y: 10) && points.count == 4)
        #expect(workspace.selectionCoverage(x: 45, y: 20) > 0.9 && workspace.selectionCoverage(x: 15, y: 40) == 0)
        #expect(workspace.undoActionName == "Undo Lasso Select")
    }

    @Test func aLassoWithNoAreaSelectsNothing() throws {
        var workspace = try canvas(.lasso)
        let steps = workspace.historySteps.count
        drag(&workspace, [(10, 10), (20, 20), (30, 30)])
        #expect(workspace.selection == nil && workspace.areaRecipe.isEmpty)
        #expect(workspace.historySteps.count == steps, "a lasso along a line adds no undo step")
    }

    @Test func thePolygonClosesOnAClickNearItsFirstCorner() throws {
        var workspace = try canvas(.polygon)
        drag(&workspace, [(10, 10)], zoom: 2)
        drag(&workspace, [(50, 10)], zoom: 2)
        #expect(workspace.areaDraft == [Point(x: 10, y: 10), Point(x: 50, y: 10)])
        drag(&workspace, [(50, 50)], zoom: 2)
        drag(&workspace, [(13, 13)], zoom: 2)
        #expect(workspace.areaRecipe.isEmpty, "4.2 px off the first corner is outside 8 points at 200%")
        drag(&workspace, [(11, 12)], zoom: 2)
        let triangle = [Point(x: 10, y: 10), Point(x: 50, y: 10), Point(x: 50, y: 50), Point(x: 13, y: 13)]
        #expect(workspace.areaRecipe.steps == [.shape(.polygon(triangle + [Point(x: 10, y: 10)]), .replace)])
        #expect(workspace.areaDraft.isEmpty)
        #expect(workspace.undoActionName == "Undo Polygon Select")
    }

    @Test func aPolygonDragLaysAnEdgeAndAnotherToolDropsTheCorners() throws {
        var workspace = try canvas(.polygon)
        drag(&workspace, [(10, 10), (40, 10)])
        #expect(workspace.areaDraft == [Point(x: 10, y: 10), Point(x: 40, y: 10)])
        workspace.selectTool(.marquee)
        workspace.selectTool(.polygon)
        #expect(workspace.areaDraft.isEmpty)
    }

    @Test func theWandSeedsAtThePressWithItsOptions() throws {
        var workspace = try canvas(.brush)
        drag(&workspace, [(4, 32), (60, 32)])
        workspace.selectTool(.wand)
        workspace.setAreaOptions(PhotoAreaOptions(tolerance: 10, contiguous: false))
        drag(&workspace, [(8, 8), (20, 20)])
        let wand = AreaShape.wand(seed: Point(x: 8, y: 8), tolerance: 10, contiguous: false, allLayers: false)
        #expect(workspace.areaRecipe.steps == [.shape(wand, .replace)])
        #expect(workspace.selectionCoverage(x: 50, y: 50) == 1 && workspace.selectionCoverage(x: 30, y: 32) == 0)
        #expect(workspace.undoActionName == "Undo Magic Wand")
    }

    /// A mouse-only user reads how each area tool works in its options: the wand clicks and the polygon closes on
    /// its first corner, so neither may say "drag".
    @Test func eachAreaToolSaysHowItWorks() {
        let hints = [PhotoTool.marquee, .ellipse, .lasso, .polygon, .wand].map(\.areaHint)
        #expect(Set(hints).count == hints.count, "each tool has its own hint")
        #expect(PhotoTool.polygon.areaHint?.contains("first corner") == true)
        #expect(PhotoTool.wand.areaHint?.hasPrefix("Click") == true)
        #expect(PhotoTool.brush.areaHint == nil)
    }
}

