// PhotoPenToolTests.swift: the Pen in Photo's palette and catalog (#5072). The
// twelve shared `path.*` commands run on Photo's document, so the CLI and an
// agent draw, close and edit a path as the canvas does; the Pen's own drag adds
// a draft point through the kernel's rules; `paths.list` and `paths.edit` read
// and pick the document's paths. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoPenToolTests {
    private func open() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.newCanvas(width: 40, height: 30)
        return workspace
    }

    private func run(_ id: String, _ params: JSONValue = .object([:]), on workspace: inout PhotoWorkspace) throws -> CommandOutcome {
        try PhotoWorkspace.catalog.run(id, params: params, on: &workspace)
    }

    private func pen(_ x: Double, _ y: Double) -> JSONValue { .object(["x": .number(x), "y": .number(y)]) }

    @Test func theCatalogHasThePenAndTheSharedPathCommands() {
        let ids = Set(PhotoWorkspace.commands.map(\.id))
        let shared = Set(PathCommands.specs(PhotoWorkspace.self).map(\.id))
        #expect(shared.count == 12)
        #expect(shared.isSubset(of: ids))
        #expect(ids.isSuperset(of: ["tool.pen", "paths.list", "paths.edit"]))
        #expect(PhotoTool.allCases.contains(.pen))
    }

    @Test func threePenPointsAndCloseAddOneClosedPath() throws {
        var workspace = try open()
        for (x, y) in [(2.0, 2.0), (20.0, 2.0), (10.0, 15.0)] { _ = try run("path.pen-add", pen(x, y), on: &workspace) }
        #expect(workspace.penDraft?.contour.anchors.count == 3)
        #expect(!workspace.canUndo)
        let outcome = try run("path.close", on: &workspace)
        #expect(outcome.undoStep == "Add Path")
        #expect(workspace.penDraft == nil)
        let contour = try #require(workspace.pathInEdit?.path.contours.first)
        #expect(contour.closed)
        #expect(contour.anchors.map(\.point) == [Point(x: 2, y: 2), Point(x: 20, y: 2), Point(x: 10, y: 15)])
        #expect(workspace.historySteps == ["New Image", "Add Path"])
    }

    @Test func movingAllPointsUnderOneDragIsOneStep() throws {
        var workspace = try open()
        _ = try run("path.draw", .object(["contours": .array([.object(["closed": .bool(false), "anchors": .array([
            .object(["x": .number(1), "y": .number(1), "kind": .string("corner")]),
            .object(["x": .number(9), "y": .number(5), "kind": .string("corner")]),
        ])])])]), on: &workspace)
        _ = try run("path.anchor-select", .object(["all": .bool(true)]), on: &workspace)
        for _ in 0..<5 { _ = try run("path.anchor-move", .object(["dx": .number(1), "dy": .number(2), "drag": .string("g1")]), on: &workspace) }
        #expect(workspace.historySteps == ["New Image", "Add Path", "Move Points"])
        #expect(workspace.pathInEdit?.path.contours.first?.anchors.map(\.point) == [Point(x: 6, y: 11), Point(x: 14, y: 15)])
        workspace.undo()
        #expect(workspace.pathInEdit?.path.contours.first?.anchors.first?.point == Point(x: 1, y: 1))
    }

    @Test func runPathSendsAnOverlayIntentThroughTheCatalog() throws {
        var workspace = try open()
        workspace.runPath(.penAdd(Point(x: 3, y: 3), handleOut: nil))
        workspace.runPath(.penAdd(Point(x: 12, y: 8), handleOut: Point(x: 16, y: 8)))
        workspace.runPath(.penAdd(Point(x: 20, y: 3), handleOut: nil))
        workspace.runPath(.finish)
        let contour = try #require(workspace.pathInEdit?.path.contours.first)
        #expect(!contour.closed)
        #expect(contour.anchors.count == 3)
        #expect(contour.anchors[1].handleOut == Point(x: 16, y: 8))
        workspace.runPath(.close)
        #expect(workspace.statusMessage != nil)
    }

    @Test func thePensDragAddsADraftPointWithItsHandle() throws {
        var workspace = try open()
        workspace.selectTool(.pen)
        workspace.drag(from: Mask.Point(x: 4, y: 4), to: Mask.Point(x: 4, y: 4))
        workspace.endDrag()
        workspace.drag(from: Mask.Point(x: 20, y: 10), to: Mask.Point(x: 26, y: 10))
        workspace.endDrag()
        let anchors = try #require(workspace.penDraft?.contour.anchors)
        #expect(anchors.map(\.point) == [Point(x: 4, y: 4), Point(x: 20, y: 10)])
        #expect(anchors[0].handleOut == nil)
        #expect(anchors[1].handleOut == Point(x: 26, y: 10))
    }

    @Test func pathsListAndEditPickWhichPathShowsItsPoints() throws {
        var workspace = try open()
        let triangle = PhotoPathsTests.triangle
        let first = try workspace.addPath(triangle, name: "Add Path")
        _ = try workspace.addPath(triangle, name: "Add Path")
        let listed = try run("paths.list", on: &workspace).result
        #expect(listed == .object(["paths": .array([
            .object(["id": .string(first), "name": .string("Path 1")]),
            .object(["id": .string("path-2"), "name": .string("Path 2")]),
        ])]))
        _ = try run("paths.edit", .object(["id": .string(first)]), on: &workspace)
        #expect(workspace.editingPathID == first)
        _ = try run("paths.edit", .object([:]), on: &workspace)
        #expect(workspace.editingPathID == nil)
        #expect(throws: CatalogError.self) { try run("paths.edit", .object(["id": .string("path-9")]), on: &workspace) }
    }
}
