// PhotoPathsTests.swift: Photo's paths on the shared pen (#5072): a Pen draft
// made by SuiteKernel's PenRules becomes a document path, a drag's edits fold
// into one undo step, undo puts the path list back, and paths survive save and
// reopen while a file from before paths opens with none. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoPathsTests {
    private let archive = LiveArchive()

    /// A closed triangle whose third anchor is smooth.
    static let triangle = VectorPath(contours: [VectorContour(anchors: [
        VectorAnchor(point: Point(x: 1, y: 1)),
        VectorAnchor(point: Point(x: 5, y: 1)),
        VectorAnchor(point: Point(x: 3, y: 4), handleIn: Point(x: 4, y: 4), handleOut: Point(x: 2, y: 4), kind: .smooth),
    ], closed: true)])

    private func open() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.newCanvas(width: 8, height: 6)
        return workspace
    }

    @Test func thePensDraftBecomesAPathAndUndoTakesItBack() throws {
        var workspace = try open()
        var draft = PenRules.add(Point(x: 1, y: 1), handleOut: nil, to: nil, scale: 1)
        draft = PenRules.add(Point(x: 6, y: 2), handleOut: nil, to: draft, scale: 1)
        let id = try workspace.addPath(try PenRules.path(draft), name: "Add Path")
        #expect(workspace.paths.map(\.name) == ["Path 1"])
        #expect(workspace.pathInEdit?.id == id)
        #expect(workspace.pathInEdit?.path.contours.first?.anchors.map(\.point) == [Point(x: 1, y: 1), Point(x: 6, y: 2)])
        #expect(workspace.undoActionName == "Undo Add Path")
        #expect(workspace.isDirty)
        workspace.undo()
        #expect(workspace.paths.isEmpty)
        #expect(workspace.pathInEdit == nil)
        workspace.redo()
        #expect(workspace.paths.map(\.id) == [id])
        #expect(workspace.pathInEdit?.id == id)
    }

    @Test func eachNewPathTakesTheLowestFreeName() throws {
        var workspace = try open()
        let first = try workspace.addPath(Self.triangle, name: "Add Path")
        let second = try workspace.addPath(Self.triangle, name: "Add Path")
        #expect(workspace.paths.map(\.name) == ["Path 1", "Path 2"])
        #expect(first != second)
        #expect(workspace.editingPathID == second)
    }

    @Test func aDragOfManyMovesIsOneStep() throws {
        var workspace = try open()
        _ = try workspace.addPath(Self.triangle, name: "Add Path")
        let steps = workspace.historySteps.count
        let first: Set = [AnchorRef(contour: 0, index: 0)]
        for i in 1...120 {
            try workspace.setPath(AnchorEdit.moved(Self.triangle, first, dx: Double(i) / 10, dy: 0), name: "Move Points", drag: "d1")
        }
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo Move Points")
        #expect(workspace.pathInEdit?.path.contours.first?.anchors.first?.point == Point(x: 13, y: 1))
        workspace.anchorSelection.replace(Array(first))
        workspace.undo()
        #expect(workspace.pathInEdit?.path == Self.triangle)
        #expect(workspace.anchorSelection.set.isEmpty)
        try workspace.setPath(AnchorEdit.moved(Self.triangle, first, dx: 1, dy: 0), name: "Move Points", drag: "d2")
        try workspace.setPath(AnchorEdit.moved(Self.triangle, first, dx: 2, dy: 0), name: "Move Points", drag: "d3")
        #expect(workspace.historySteps.count == steps + 2)
    }

    @Test func nothingToEditOrNoImageRefuses() throws {
        var empty = PhotoWorkspace(services: .fake)
        #expect(empty.pathHelp != nil)
        #expect(throws: CatalogError.self) { try empty.addPath(Self.triangle, name: "Add Path") }
        var workspace = try open()
        #expect(workspace.pathHelp == nil)
        #expect(throws: CatalogError.self) { try workspace.setPath(Self.triangle, name: "Move Points", drag: nil) }
        #expect(!workspace.canUndo)
    }

    @Test func pathsSaveAndReopen() throws {
        var workspace = try open()
        _ = try workspace.addPath(Self.triangle, name: "Add Path")
        let package = try workspace.documentPackage(archive: archive, codec: RawCodec())
        var reopened = PhotoWorkspace(services: .fake)
        try reopened.openDocument(package, name: "Shapes.ora", archive: archive, codec: RawCodec())
        #expect(reopened.paths == workspace.paths)
        #expect(!reopened.isDirty)
        #expect(!reopened.canUndo)
        let next = try reopened.addPath(Self.triangle, name: "Add Path")
        #expect(!workspace.paths.map(\.id).contains(next))
        #expect(reopened.paths.map(\.name) == ["Path 1", "Path 2"])
    }

    @Test func aDocumentWithoutPathsSavesAsBefore() throws {
        let workspace = try open()
        let package = try workspace.documentPackage(archive: archive, codec: RawCodec())
        let json = String(decoding: try #require(package.files["photo/document.json"]), as: UTF8.self)
        #expect(!json.contains("\"paths\""))
    }

    @Test func aFileFromBeforePathsOpensWithNone() throws {
        let data = try Data(contentsOf: PhotoImagingTests.legacy)
        let opened = try PhotoHeadless.open(data, name: "adjust-legacy.ora")
        #expect(opened.workspace.paths.isEmpty)
    }

    @Test func aNewImageStartsWithNoPaths() throws {
        var workspace = try open()
        _ = try workspace.addPath(Self.triangle, name: "Add Path")
        workspace.penDraft = PenRules.add(Point(x: 2, y: 2), handleOut: nil, to: nil, scale: 1)
        try workspace.newCanvas(width: 4, height: 4)
        #expect(workspace.paths.isEmpty)
        #expect(workspace.penDraft == nil)
        #expect(workspace.editingPathID == nil)
    }

    @Test func aFlatFileAsksBeforeDroppingPaths() throws {
        var workspace = try open()
        workspace.didSave(as: "beach.png", kind: .image(.png))
        #expect(workspace.saveAction == .writeImage(.png))
        _ = try workspace.addPath(Self.triangle, name: "Add Path")
        #expect(workspace.needsDocument)
        #expect(workspace.saveAction == .askKeepLayers(.png))
    }

    @Test func pathEditsMoveTheRevisionWithoutRedrawingTheCanvas() throws {
        var workspace = try open()
        let opened = workspace.revision
        _ = try workspace.addPath(Self.triangle, name: "Add Path")
        #expect(workspace.revision > opened)
        #expect(workspace.damage(since: opened) == .none)
        let added = workspace.revision
        workspace.undo()
        #expect(workspace.revision > added)
    }
}
