// PhotoLayerMenuTests.swift: the Layer menu's enable state and Show/Hide
// title as a user moves through no image, a new image, more layers, hiding
// and deleting. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoLayerMenuTests {
    @Test func everythingIsDisabledWithNoImageOpen() {
        let workspace = PhotoWorkspace()
        #expect(!workspace.canAddLayer)
        #expect(!workspace.canDeleteSelectedLayer)
        #expect(!workspace.canEditSelectedLayer)
        #expect(workspace.visibilityCommandTitle == "Hide Layer")
    }

    @Test func aNewImageEnablesAllButDelete() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        #expect(workspace.canAddLayer)
        #expect(workspace.canEditSelectedLayer)
        #expect(!workspace.canDeleteSelectedLayer)
    }

    @Test func deleteFollowsTheLayerCount() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        workspace.addLayer()
        #expect(workspace.canDeleteSelectedLayer)
        if let id = workspace.selectedLayerID { workspace.removeLayer(id) }
        #expect(!workspace.canDeleteSelectedLayer)
        #expect(workspace.canEditSelectedLayer)
    }

    @Test func showHideTitleSaysWhatItWillDo() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        let id = try #require(workspace.selectedLayerID)
        #expect(workspace.visibilityCommandTitle == "Hide Layer")
        workspace.toggleVisibility(id)
        #expect(workspace.visibilityCommandTitle == "Show Layer")
        workspace.toggleVisibility(id)
        #expect(workspace.visibilityCommandTitle == "Hide Layer")
    }

    @Test func titleFollowsTheSelectedLayer() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        let background = try #require(workspace.selectedLayerID)
        workspace.toggleVisibility(background)
        workspace.addLayer()
        #expect(workspace.visibilityCommandTitle == "Hide Layer")
        workspace.selectLayer(background)
        #expect(workspace.visibilityCommandTitle == "Show Layer")
    }
}
