// PhotoAreaOutlineTests.swift (area-selection AR-11): the outline the ants follow (`areaOutline`) and the Select
// menu's area items (PhotoSelectionMask.swift, PhotoCommandCatalog.swift). Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoAreaOutlineTests {
    func canvas(_ tool: PhotoTool) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 64, height: 64)
        workspace.selectTool(tool)
        return workspace
    }

    func drag(_ workspace: inout PhotoWorkspace, _ from: (Double, Double), _ to: (Double, Double)) {
        workspace.drag(from: Mask.Point(x: from.0, y: from.1), to: Mask.Point(x: to.0, y: to.1), modifiers: [])
        workspace.endDrag()
    }

    /// The smallest box around every point of `outline`.
    func bounds(_ outline: [[Point]]) -> Rect? { Rect(enclosing: outline.flatMap { $0 }) }

    @Test func aRectangleIsOutlinedByItsCorners() throws {
        var workspace = try canvas(.marquee)
        #expect(workspace.areaOutline.isEmpty)
        drag(&workspace, (10, 12), (40, 30))
        #expect(workspace.areaOutline == [[Point(x: 10, y: 12), Point(x: 40, y: 12), Point(x: 40, y: 30), Point(x: 10, y: 30)]])
        workspace.deselect()
        #expect(workspace.areaOutline.isEmpty)
    }

    @Test func anEllipseIsOutlinedWhereItsCoverageCrossesHalf() throws {
        var workspace = try canvas(.ellipse)
        drag(&workspace, (10, 10), (50, 40))
        let box = try #require(bounds(workspace.areaOutline))
        #expect(abs(box.minX - 10) <= 1 && abs(box.maxX - 50) <= 1 && abs(box.minY - 10) <= 1 && abs(box.maxY - 40) <= 1)
        #expect(workspace.areaOutline.count == 1)
        #expect(workspace.areaOutline.first.map { $0.count > 8 } == true, "an ellipse is more than its box's corners")
    }

    @Test func undoAndInvertMoveTheOutline() throws {
        var workspace = try canvas(.ellipse)
        drag(&workspace, (10, 10), (50, 40))
        let ellipse = workspace.areaOutline
        _ = try PhotoWorkspace.catalog.run("select.invert", params: .object([:]), on: &workspace)
        #expect(workspace.areaOutline != ellipse && !workspace.areaOutline.isEmpty)
        workspace.undo()
        #expect(workspace.areaOutline == ellipse)
        workspace.undo()
        #expect(workspace.areaOutline.isEmpty)
    }

    @Test func theSelectMenuNamesTheAreaCommands() {
        let workspace = PhotoWorkspace()
        let titles = ["select.invert", "select.feather", "select.expand", "select.contract", "select.reselect"].map(workspace.menuTitle)
        #expect(titles == ["Invert", "Feather…", "Expand…", "Contract…", "Reselect"])
    }
}
