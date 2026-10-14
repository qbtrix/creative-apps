// PhotoSelectAllMenuTests.swift: Photo's Select > All is disabled while a sheet
// (Straighten, Image Size, Export) or the rename alert is up, so Command-A
// reaches the sheet's text field (#575); with nothing presented it is enabled
// and selects the whole canvas. macOS only.
import PhotoModel
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoSelectAllMenuTests {
    @Test func selectAllIsDisabledWhileASheetIsUp() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 800, height: 600)
        let straightening = PhotoMenu(model: model, isPresenting: true, perform: { _ in })
        #expect(straightening.hasImage && !straightening.canSelectAll)
    }

    @Test func selectAllSelectsTheCanvasWithNoSheet() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 800, height: 600)
        var sent: [PhotoIntent] = []
        let menu = PhotoMenu(model: model, perform: { sent.append($0) })
        #expect(menu.canSelectAll && !PhotoMenu().canSelectAll)
        menu.perform(.selectAll)
        for intent in sent { if case .selectAll = intent { model.selectAll() } }
        #expect(model.canDeselect && model.selection?.width == 800 && model.selection?.height == 600)
    }
}
