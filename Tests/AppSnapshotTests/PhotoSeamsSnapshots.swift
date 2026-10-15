// PhotoSeamsSnapshots.swift: the Photo window under `-PhotoFixture sample`
// (S-12): the sample fixture on the fakes, its picture on the canvas and the
// "Preview data" pill in the status line. Writes photo-preview-pill-dark.png
// (the editor is dark on purpose, as in PhotoEditorSnapshots). macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoSeamsSnapshots {
    @Test func previewPill() throws {
        let model = try PhotoWorkspace.fixture(.sample)
        #expect(model.isPreviewData)
        let tiles = try photoTiles(model)
        try snapshot(
            PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1, tab: .adjust),
            name: "photo-preview-pill-dark", scheme: .dark)
    }
}
