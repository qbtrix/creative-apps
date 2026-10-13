// PhotoInspectorHeaderTests.swift: the text Photo's panel header and viewer
// status bar show, built in PhotoModel so the views only read it. Runs on
// Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoInspectorHeaderTests {
    @Test func aNewImageListsItsSizeColorSpaceAndLayerCount() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 1920, height: 1080)
        #expect(workspace.inspectorHeaderTitle == "Untitled")
        #expect(workspace.inspectorHeaderDetails == ["1920 × 1080 px", "sRGB · 1 layer"])
        workspace.addLayer()
        #expect(workspace.inspectorHeaderDetails == ["1920 × 1080 px", "sRGB · 2 layers"])
    }

    @Test func noCanvasHasNoDetails() {
        let workspace = PhotoWorkspace()
        #expect(workspace.inspectorHeaderDetails.isEmpty)
        #expect(workspace.viewerSizeText == "No image")
    }

    /// The details show exactly when the inspector shows a layer, so the
    /// no-selection state has none too.
    @Test func detailsFollowTheInspectorContent() throws {
        var workspace = PhotoWorkspace()
        #expect(workspace.inspectorContent == .noImage && workspace.inspectorHeaderDetails.isEmpty)
        try workspace.newCanvas(width: 4, height: 3)
        workspace.selectLayer("no-such-layer")
        guard case .layer = workspace.inspectorContent else {
            #expect(workspace.inspectorHeaderDetails.isEmpty)
            return
        }
        #expect(workspace.inspectorHeaderDetails == ["4 × 3 px", "sRGB · 1 layer"])
    }

    @Test func extremeSizesFormatWithoutATrap() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 1, height: 1)
        #expect(workspace.inspectorHeaderDetails.first == "1 × 1 px")
        let largest = PhotoWorkspace.headerDetails(width: Int.max, height: Int.max, layerCount: Int.max)
        #expect(largest == ["\(Int.max) × \(Int.max) px", "sRGB · \(Int.max) layers"])
    }

    @Test func theStatusSizeAddsTheSelection() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 1920, height: 1080)
        #expect(workspace.viewerSizeText == "1920 × 1080 px")
        workspace.selectAll()
        #expect(workspace.viewerSizeText == "1920 × 1080 px  ·  Selection 1920 × 1080")
    }
}
