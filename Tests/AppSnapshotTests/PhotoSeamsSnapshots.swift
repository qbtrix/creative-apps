// PhotoSeamsSnapshots.swift: the Photo window under `-PhotoFixture sample`
// (S-12): the sample fixture on the fakes, its picture on the canvas and the
// "Preview data" pill in the status line (with its tooltip), and the
// Eyedropper's Tool Options section (its hint, size chips and brush colour).
// Writes photo-preview-pill-dark.png (the editor is dark on purpose, as in
// PhotoEditorSnapshots) and photo-eyedropper-options-{light,dark}.png. macOS only.
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
    /// each other tool's does, then shows its size chips on Point and the brush
    /// colour a pick lands in. It draws the section itself: PhotoEditor has no
    /// inspector, so a shot of the editor showed none of it.
    @Test func eyedropperOptionsHint() throws {
        var model = try PhotoWorkspace.fixture(.sample)
        model.selectTool(.eyedropper)
        #expect(model.tool == .eyedropper)
        #expect(model.sampleSize == .point)
        #expect(ToolOptionsSection.eyedropperHint == "Click the image to pick a color for the brush.")
        for scheme in [ColorScheme.light, .dark] {
            let view = ToolOptionsSection(model: model, perform: { _ in })
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(view, name: "photo-eyedropper-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
