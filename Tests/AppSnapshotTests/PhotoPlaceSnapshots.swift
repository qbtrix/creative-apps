// PhotoPlaceSnapshots.swift (place-image PP-4): the Photo window (PhotoEditor) after File > Place…, in the
// packet's two screens (docs/blueprints/photo/features/place-image.md, Screens and states): `logo`, a 200 x 100
// PNG placed on an 800 x 600 white image, its layer `logo` centred above Background in the Layers panel; and
// `refused`, a text file placed, nothing added and the reason in the status line. The place runs the way the menu
// and the drop run it (`PhotoWorkspace.place(_:at:)`). `logo` waits on PP-5, which builds the place bodies on
// the PP-1 stubs; `refused` shows Photo's reason, "Photo places PNG, JPEG or SVG
// files.". Writes photo-place-logo-light/-dark.png and photo-place-refused-light/-dark.png. macOS only.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoPlaceSnapshots {
    /// An 800 x 600 white image, its Background layer selected.
    private func opened() throws -> PhotoWorkspace {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 800, height: 600)
        return model
    }

    /// A 200 x 100 red PNG, as the journey kit's `logo.png`.
    private func logoPNG() throws -> Data {
        try PNG.write(try PixelBuffer(width: 200, height: 100, fill: RGBA(r: 1, g: 0, b: 0, a: 1)))
    }

    private func shoot(_ state: String, _ model: PhotoWorkspace) throws {
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "photo-place-\(state)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test(.disabled("waits on PP-5")) func logo() throws {
        var model = try opened()
        model.place([(name: "logo.png", data: try logoPNG())], at: nil)
        #expect(model.statusMessage == nil, "the place refused: \(model.statusMessage ?? "")")
        #expect(model.layers.count == 2, "the place added \(model.layers.count - 1) layers, not 1")
        #expect(model.layers.contains { $0.name == "logo" }, "no layer named logo")
        try shoot("logo", model)
    }

    @Test func refused() throws {
        var model = try opened()
        model.place([(name: "notes.txt", data: Data("not an image".utf8))], at: nil)
        #expect(model.statusMessage == "Photo places PNG, JPEG or SVG files.", "a text place left no reason in the status line")
        #expect(model.layers.count == 1, "a text place added a layer")
        #expect(!model.canUndo, "a text place made an undo step")
        try shoot("refused", model)
    }
}
