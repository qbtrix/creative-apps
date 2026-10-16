// PhotoSeamsSnapshots.swift: the Photo window under `-PhotoFixture sample`
// (S-12): the sample fixture on the fakes, its picture on the canvas and the
// "Preview data" pill in the status line (with its tooltip), and the
// Eyedropper's Tool Options hint. Writes photo-preview-pill-dark.png and
// photo-eyedropper-options-dark.png (the editor is dark on purpose, as in
// PhotoEditorSnapshots). macOS only.
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
            PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
            name: "photo-preview-pill-dark", scheme: .dark)
        #expect(PhotoStatusLine.previewHelp == "This window shows built-in sample data, not a file on disk.")
    }

    /// The enabled Eyedropper's Tool Options section says what it does, as
    /// each other tool's does, instead of showing an empty section.
    @Test func eyedropperOptionsHint() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.selectTool(.eyedropper)
        #expect(model.tool == .eyedropper)
        #expect(ToolOptionsSection.eyedropperHint == "Click the image to pick a color for the brush.")
        try snapshot(
            PhotoEditor(model: model, tiles: try photoTiles(model), renderMilliseconds: 8, zoom: 1),
            name: "photo-eyedropper-options-dark", scheme: .dark)
    }
}
