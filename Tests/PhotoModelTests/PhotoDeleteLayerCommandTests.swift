// PhotoDeleteLayerCommandTests.swift: the Delete Layer toolbar command as a
// user drives it. PhotoWindow enables it while `canRemoveLayer` holds and a
// layer is selected, and a click removes the selected layer. These tests walk
// that state through New Image, New Layer, repeated clicks and a second New
// Image. Runs on Linux and macOS.
import PhotoModel
import Testing

/// What PhotoWindow passes to DeleteLayerCommand as `isEnabled`.
private func deleteLayerEnabled(_ workspace: PhotoWorkspace) -> Bool {
    workspace.canRemoveLayer && workspace.selectedLayerID != nil
}

/// What a Delete Layer click does in PhotoWindow.
private func clickDeleteLayer(_ workspace: inout PhotoWorkspace) -> Bool {
    guard let id = workspace.selectedLayerID else { return false }
    return workspace.removeLayer(id)
}

@Suite struct PhotoDeleteLayerCommandTests {
    @Test func disabledWithNoImageOpenAndAClickChangesNothing() {
        var workspace = PhotoWorkspace()
        #expect(!deleteLayerEnabled(workspace))
        #expect(!clickDeleteLayer(&workspace))
        #expect(workspace.layers.isEmpty && workspace.canvas == nil)
    }

    @Test func disabledOnANewImageAndEnabledOnceALayerIsAdded() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        #expect(!deleteLayerEnabled(workspace))
        workspace.addLayer()
        #expect(deleteLayerEnabled(workspace))
    }

    @Test(arguments: [1, 2, 5, 12])
    func clickingWhileEnabledDrainsTheStackToTheBackground(extra: Int) throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        for _ in 0..<extra { workspace.addLayer() }
        var clicks = 0
        while deleteLayerEnabled(workspace) {
            let before = workspace.layers.count
            #expect(clickDeleteLayer(&workspace))
            #expect(workspace.layers.count == before - 1)
            #expect(workspace.selectedLayer != nil)
            clicks += 1
        }
        #expect(clicks == extra)
        #expect(workspace.layers.map(\.name) == ["Background"])
        // The disabled button can't fire, but even a stray click is refused.
        #expect(!clickDeleteLayer(&workspace))
        #expect(workspace.layers.count == 1)
    }

    @Test func enabledStateFollowsTheSelectionAndAnyLayerCanBeDeleted() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        workspace.addLayer()
        workspace.addLayer()
        for id in workspace.layers.map(\.id) {
            var copy = workspace
            copy.selectLayer(id)
            #expect(deleteLayerEnabled(copy))
            #expect(clickDeleteLayer(&copy))
            #expect(!copy.layers.contains { $0.id == id })
        }
    }

    @Test func aSecondNewImageDisablesItAgain() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        workspace.addLayer()
        workspace.addLayer()
        #expect(deleteLayerEnabled(workspace))
        try workspace.newCanvas(width: 8, height: 8)
        #expect(!deleteLayerEnabled(workspace))
    }

    @Test func aRejectedNewImageKeepsItEnabled() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        workspace.addLayer()
        #expect(throws: (any Error).self) { try workspace.newCanvas(width: 0, height: 0) }
        #expect(deleteLayerEnabled(workspace))
    }
}
