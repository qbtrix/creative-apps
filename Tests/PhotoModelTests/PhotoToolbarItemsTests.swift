// PhotoToolbarItemsTests.swift: the window toolbar's eight commands (PS-1):
// which ones say why they can't run with no image, Undo and Redo naming the
// edit, the photo.bar.* identifiers, and the subtitle's save state through a
// new image, a stroke, its undo and a save. Runs on Linux and macOS.
import PhotoModel
import Testing

@Suite struct PhotoToolbarItemsTests {
    /// A new 8 x 8 image with one brush stroke.
    private func stroked() throws -> PhotoWorkspace {
        var workspace = try whiteImage(8, 8)
        workspace.selectTool(.brush)
        workspace.drag(from: point(1, 1), to: point(6, 6))
        workspace.endDrag()
        return workspace
    }

    @Test func withNoImageOnlyOpenCanRun() {
        let workspace = PhotoWorkspace()
        #expect(PhotoToolbarItem.open.unavailableHelp(in: workspace) == nil)
        for item in PhotoToolbarItem.allCases where item != .open {
            #expect(item.unavailableHelp(in: workspace) == "Open or create an image first.", "\(item)")
        }
        #expect(PhotoToolbarItem.saveState(of: workspace) == nil)
    }

    @Test func aNewImageEnablesSaveAndExportButNotUndo() throws {
        let workspace = try whiteImage(8, 8)
        for item in [PhotoToolbarItem.open, .save, .export, .zoomOut, .fit, .zoomIn] {
            #expect(item.unavailableHelp(in: workspace) == nil, "\(item)")
        }
        #expect(PhotoToolbarItem.undo.unavailableHelp(in: workspace) == "Nothing to undo.")
        #expect(PhotoToolbarItem.redo.unavailableHelp(in: workspace) == "Nothing to redo.")
        #expect(PhotoToolbarItem.saveState(of: workspace) == nil)
    }

    @Test func aStrokeIsEditedAndUndoNamesIt() throws {
        var workspace = try stroked()
        #expect(PhotoToolbarItem.undo.unavailableHelp(in: workspace) == nil)
        #expect(PhotoToolbarItem.undo.title(in: workspace) == "Undo Paint")
        #expect(PhotoToolbarItem.saveState(of: workspace) == "Edited")
        workspace.undo()
        #expect(PhotoToolbarItem.saveState(of: workspace) != "Edited")
        #expect(PhotoToolbarItem.redo.title(in: workspace) == "Redo Paint")
        #expect(PhotoToolbarItem.redo.unavailableHelp(in: workspace) == nil)
    }

    @Test func aSavedFileReadsSaved() throws {
        var workspace = try stroked()
        workspace.didSave(as: "beach.ora", kind: .document)
        #expect(PhotoToolbarItem.saveState(of: workspace) == "Saved")
    }

    @Test func titlesAndSymbolsMatchTheTopBar() throws {
        let workspace = try whiteImage(8, 8)
        let titles = PhotoToolbarItem.allCases.map { $0.title(in: workspace) }
        #expect(titles == ["Open", "Save", "Export", "Undo", "Redo", "Zoom Out", "Fit on Screen", "Zoom In"])
        #expect(PhotoToolbarItem.export.systemImage == "square.and.arrow.up")
        #expect(Set(PhotoToolbarItem.allCases.map(\.systemImage)).count == PhotoToolbarItem.allCases.count)
    }

    @Test func identifiersAreUniqueAndPhotoBar() {
        let ids = PhotoToolbarItem.allCases.map(\.identifier)
        #expect(ids == [
            "photo.bar.open", "photo.bar.save", "photo.bar.export", "photo.bar.undo",
            "photo.bar.redo", "photo.bar.zoom-out", "photo.bar.fit", "photo.bar.zoom-in",
        ])
        #expect(Set(ids).count == ids.count)
    }
}
