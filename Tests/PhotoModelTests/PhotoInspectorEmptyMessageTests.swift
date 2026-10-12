// PhotoInspectorEmptyMessageTests.swift: the inspector's empty-state messages
// name only actions Photo has (it has New Image, not Open).
// Runs on Linux and macOS.
import PhotoModel
import Testing

@Test func noImageMessageOffersNewImageNotOpen() throws {
    let message = try #require(PhotoWorkspace().inspectorContent.emptyStateMessage)
    #expect(message == "Create a new image to adjust it.")
    #expect(!message.contains("Open"))
}

@Test func noSelectionMessageAsksForALayer() {
    #expect(PhotoInspectorContent.noSelection.emptyStateMessage == "Select a layer to adjust it.")
}

@Test func layerContentHasNoEmptyStateMessage() throws {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 2, height: 2)
    #expect(workspace.inspectorContent.emptyStateMessage == nil)
}
