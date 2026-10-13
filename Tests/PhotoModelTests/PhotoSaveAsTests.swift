// PhotoSaveAsTests.swift: the file name Export and Save As offer, and Save As
// renaming the document (window title, top bar, panel header) without an undo
// step. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoSaveAsTests {
    private func opened(_ name: String) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: [255, 0, 0, 255], width: 1, height: 1, name: name)
        return workspace
    }

    @Test func theOfferedNameSwapsTheExtensionForTheFormat() throws {
        #expect(try opened("tools.PNG").fileName(for: .png) == "tools.png")
        #expect(try opened("beach.HEIC").fileName(for: .jpeg) == "beach.jpg")
        #expect(try opened("a..b.jpeg").fileName(for: .png) == "a..b.png")
        #expect(try opened("scan").fileName(for: .png) == "scan.png")
        #expect(try opened(".png").fileName(for: .jpeg) == ".png.jpg")
    }

    @Test func aNewImageIsOfferedAsUntitled() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 4, height: 4)
        #expect(workspace.fileName(for: .png) == "Untitled.png")
        #expect(workspace.fileName(for: .jpeg) == "Untitled.jpg")
    }

    @Test func saveAsRenamesTheDocumentButIsNoUndoStep() throws {
        var workspace = try opened("tools.png")
        workspace.rotateImage(.degrees90)
        let revision = workspace.revision
        workspace.didSave(as: "copy.jpg")
        #expect(workspace.documentName == "copy.jpg")
        #expect(workspace.inspectorHeaderTitle == "copy.jpg")
        #expect(workspace.undoActionName == "Undo Rotate")
        #expect(workspace.revision == revision)
        workspace.undo()
        #expect(workspace.documentName == "copy.jpg")
    }

    @Test func saveAsWithNoImageNamesNothing() {
        var workspace = PhotoWorkspace()
        workspace.didSave(as: "copy.png")
        #expect(workspace.documentName == nil)
    }
}
