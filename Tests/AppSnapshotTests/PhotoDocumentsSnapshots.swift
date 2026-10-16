// PhotoDocumentsSnapshots.swift: the Photo window's document state
// (photo-documents D-8) through the real PhotoFileArea at 1024 x 768: an
// opened image after a brush stroke (the accent dot and "Edited" in the top
// bar's `photo.bar.saved`) and the same image after a failed save ("Not
// saved" in stateError with a triangle). Writes photo-unsaved-light.png,
// photo-unsaved-dark.png, photo-not-saved-light.png and
// photo-not-saved-dark.png. Keep layers? is a system confirmation dialog,
// shown in its own sheet window, which the hosting view's bitmap doesn't
// draw, so it has no snapshot here. macOS only.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoDocumentsSnapshots {
    /// "beach.png", a 640 x 480 gradient, opened clean, then one brush stroke.
    private func edited() throws -> PhotoWorkspace {
        let (w, h) = (640, 480)
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                bytes[i] = UInt8(40 + x * 180 / w)
                bytes[i + 1] = UInt8(80 + y * 120 / h)
                bytes[i + 2] = 200
            }
        }
        var model = PhotoWorkspace()
        try model.open(rgba8: bytes, width: w, height: h, name: "beach.png")
        #expect(!model.isDirty)
        model.selectTool(.brush)
        model.setToolOption(.size(24))
        model.drag(from: Mask.Point(x: 80, y: 80), to: Mask.Point(x: 80, y: 80))
        model.drag(from: Mask.Point(x: 80, y: 80), to: Mask.Point(x: 560, y: 400))
        model.endDrag()
        return model
    }

    private func shoot(_ state: String, _ model: PhotoWorkspace, files: PhotoFileSession) throws {
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 0.5)
                    .modifier(PhotoFileArea(model: model, files: files, perform: { _ in }))
                    .frame(width: 1024, height: 768),
                name: "photo-\(state)-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func unsaved() throws {
        let model = try edited()
        #expect(model.isDirty)
        #expect(model.saveStatus(autosaved: false, saveFailed: false) == .edited)
        #expect(PhotoSaveStatus.edited.title == "Edited")
        try shoot("unsaved", model, files: PhotoFileSession())
    }

    @Test func notSaved() throws {
        let model = try edited()
        let files = PhotoFileSession()
        files.saveFailed = true
        #expect(model.saveStatus(autosaved: false, saveFailed: files.saveFailed) == .notSaved)
        try shoot("not-saved", model, files: files)
    }

    /// No image, no status; the notes name their work.
    @Test func noImageNoStatusAndNotes() {
        #expect(PhotoWorkspace().saveStatus(autosaved: false, saveFailed: true) == nil)
        #expect(PhotoFileWork.saving.note == "Saving…")
        #expect(PhotoFileWork.opening.note == "Opening…")
        #expect(PhotoFileWork.saving.identifier == "photo.file.saving")
        #expect(PhotoFileWork.opening.identifier == "photo.file.opening")
    }
}
