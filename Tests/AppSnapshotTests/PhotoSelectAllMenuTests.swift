// PhotoSelectAllMenuTests.swift: Select > All is on with an image open and no
// sheet, and off while a sheet is up, so Command-A reaches the sheet's text
// field instead of selecting the canvas (#575). macOS only.
import PhotoModel
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoSelectAllMenuTests {
    @Test func selectAllIsOffWhileASheetIsUp() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 800, height: 600)
        var sent: [PhotoIntent] = []
        let open = PhotoMenu(model: model, perform: { sent.append($0) })
        #expect(open.canSelectAll)
        open.perform(.selectAll)
        #expect(sent.count == 1)
        model.selectAll()
        #expect(model.canDeselect)

        #expect(!PhotoMenu(model: model, sheetPresented: true, perform: { _ in }).canSelectAll)
        #expect(!PhotoMenu(model: PhotoWorkspace(), perform: { _ in }).canSelectAll)
    }
}
