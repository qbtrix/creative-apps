// PhotoInspectorHeaderEdgeTests.swift: edge cases for the panel header and
// viewer status text (#182): they follow undo, redo, crop, a reopen and a
// cleared selection, so the header never shows a stale size or layer count.
// Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoInspectorHeaderEdgeTests {
    @Test func theLayerCountFollowsUndoAndRedo() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 8, height: 8)
        workspace.addLayer()
        workspace.addLayer()
        #expect(workspace.inspectorHeaderDetails.last == "sRGB · 3 layers")
        workspace.undo()
        #expect(workspace.inspectorHeaderDetails.last == "sRGB · 2 layers")
        workspace.undo()
        #expect(workspace.inspectorHeaderDetails.last == "sRGB · 1 layer")
        workspace.redo()
        #expect(workspace.inspectorHeaderDetails.last == "sRGB · 2 layers")
    }

    @Test func deletingBackToOneLayerSaysLayerNotLayers() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 8, height: 8)
        workspace.addLayer()
        let added = try #require(workspace.selectedLayerID)
        let removed = workspace.removeLayer(added)
        #expect(removed)
        #expect(workspace.inspectorHeaderDetails == ["8 × 8 px", "sRGB · 1 layer"])
    }

    @Test func anOpenedFileTitlesTheHeaderAndAReopenReplacesIt() throws {
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: [UInt8](repeating: 255, count: 4 * 6), width: 3, height: 2, name: "beach.png")
        #expect(workspace.inspectorHeaderTitle == "beach.png")
        #expect(workspace.inspectorHeaderDetails == ["3 × 2 px", "sRGB · 1 layer"])
        try workspace.newCanvas(width: 5, height: 4)
        #expect(workspace.inspectorHeaderTitle == "Untitled")
        #expect(workspace.inspectorHeaderDetails == ["5 × 4 px", "sRGB · 1 layer"])
        #expect(workspace.viewerSizeText == "5 × 4 px")
    }

    @Test func aCropChangesBothSizeTextsAndUndoRestoresThem() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 64, height: 64)
        stroke(&workspace, .crop, from: point(8, 8), to: point(40, 32))
        workspace.applyCrop()
        #expect(workspace.inspectorHeaderDetails.first == "32 × 24 px")
        #expect(workspace.viewerSizeText.hasPrefix("32 × 24 px"))
        workspace.undo()
        #expect(workspace.inspectorHeaderDetails.first == "64 × 64 px")
        #expect(workspace.viewerSizeText.hasPrefix("64 × 64 px"))
    }

    @Test func deselectingDropsTheSelectionFromTheStatusText() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 10, height: 20)
        workspace.selectAll()
        #expect(workspace.viewerSizeText == "10 × 20 px  ·  Selection 10 × 20")
        workspace.deselect()
        #expect(workspace.viewerSizeText == "10 × 20 px")
    }

    @Test func aMarqueeSelectionShowsItsOwnSize() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 64, height: 64)
        stroke(&workspace, .marquee, from: point(4, 4), to: point(20, 12))
        let selection = try #require(workspace.selection)
        #expect(workspace.viewerSizeText == "64 × 64 px  ·  Selection \(selection.width) × \(selection.height)")
    }

    @Test func extremeLayerCountsAndSizesStayPlain() {
        #expect(PhotoWorkspace.headerDetails(width: 0, height: 0, layerCount: 0) == ["0 × 0 px", "sRGB · 0 layers"])
        #expect(PhotoWorkspace.headerDetails(width: Int.min, height: -1, layerCount: -1)
            == ["\(Int.min) × -1 px", "sRGB · -1 layers"])
    }
}
