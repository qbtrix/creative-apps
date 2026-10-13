// PhotoSelectionTests.swift: select a rectangle, then delete or fill it
// (#194). Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoSelectionTests {
    @Test func aMarqueeDragSelectsTheRectangle() throws {
        var workspace = try whiteImage()
        stroke(&workspace, .marquee, from: point(8, 8), to: point(40, 40))
        let selection = try #require(workspace.selection)
        #expect(selection == PixelRect(x: 8, y: 8, width: 32, height: 32))
        #expect(selection.width * selection.height == 1024)
    }

    @Test func deleteClearsTheSelectionAndUndoRestoresIt() throws {
        var workspace = try whiteImage()
        let before = try workspace.composite()
        stroke(&workspace, .marquee, from: point(8, 8), to: point(40, 40))
        workspace.deleteSelection()
        #expect(try canvasPixel(workspace, 20, 20) == RGBA.clear)
        #expect(try canvasPixel(workspace, 4, 4) == RGBA(r: 1, g: 1, b: 1, a: 1))
        #expect(workspace.undoActionName == "Undo Delete")
        workspace.undo()
        #expect(try workspace.composite() == before)
    }

    @Test func fillPaintsTheToolColorAndUndoRestoresIt() throws {
        var workspace = try whiteImage()
        let before = try workspace.composite()
        workspace.setToolOption(.color(red: 0, green: 0, blue: 255))
        stroke(&workspace, .marquee, from: point(8, 8), to: point(40, 40))
        workspace.fillSelection()
        #expect(try canvasPixel(workspace, 20, 20) == RGBA(r: 0, g: 0, b: 1, a: 1))
        #expect(workspace.undoActionName == "Undo Fill")
        workspace.undo()
        #expect(try workspace.composite() == before)
    }

    @Test func selectAllDeselectAndAClick() throws {
        var workspace = try whiteImage()
        #expect(!workspace.canDeselect && workspace.canSelectAll)
        workspace.selectAll()
        #expect(workspace.selection == PixelRect(x: 0, y: 0, width: 64, height: 64))
        workspace.deselect()
        #expect(workspace.selection == nil)
        stroke(&workspace, .marquee, from: point(8, 8), to: point(40, 40))
        stroke(&workspace, .marquee, from: point(20, 20), to: point(20, 20))
        #expect(workspace.selection == nil, "a click deselects")
        #expect(!workspace.canEditSelection)
    }

    @Test func aSelectionIsClippedToTheCanvas() throws {
        var workspace = try whiteImage(10, 10)
        stroke(&workspace, .marquee, from: point(-5, 4), to: point(30, 6))
        #expect(workspace.selection == PixelRect(x: 0, y: 4, width: 10, height: 2))
    }
}
