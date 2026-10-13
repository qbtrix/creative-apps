// PhotoInspectorContentTests.swift: which state Photo's inspector shows.
// Runs on Linux and macOS.
import PhotoModel
import Testing

@Test func inspectorShowsNoImageWithNoCanvas() {
    #expect(PhotoWorkspace().inspectorContent == .noImage)
}

@Test func inspectorShowsNoImageAfterAFailedNewCanvas() {
    var workspace = PhotoWorkspace()
    try? workspace.newCanvas(width: 0, height: 10)
    #expect(workspace.inspectorContent == .noImage)
}

@Test func inspectorShowsTheSelectedLayerWithTheCanvasSize() throws {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 4, height: 3)
    let background = try #require(workspace.selectedLayer)
    #expect(workspace.inspectorContent == .layer(background, width: 4, height: 3))
}

@Test func inspectorFollowsTheSelection() throws {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 2, height: 2)
    workspace.addLayer()
    workspace.selectLayer("layer-1")
    guard case .layer(let layer, _, _) = workspace.inspectorContent else {
        Issue.record("expected a layer")
        return
    }
    #expect(layer.name == "Background")
}

@Test func noImageMessageNamesOpenAndNewImage() {
    let message = PhotoInspectorContent.noImageMessage
    #expect(message.contains("Open"))
    #expect(message.contains("File > New Image"))
}
