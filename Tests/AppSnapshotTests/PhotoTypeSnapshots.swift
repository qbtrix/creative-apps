// PhotoTypeSnapshots.swift: the Type tool's box (text-layers TX-3) on a 640 x 480 white image.
// `box` writes photo-type-box-light/dark.png: the Type tool picked, its hint in Tool Options, and a
// box clicked open at (80, 120) holding "SALE" in PhotoTextBoxOverlay's field. macOS only.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoTypeSnapshots {
    @Test func box() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        model.selectTool(.text)
        let at = Mask.Point(x: 80, y: 120)
        model.drag(from: at, to: at)
        model.endDrag()
        model.typeText("SALE")
        #expect(model.textBox?.draft == "SALE")
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "photo-type-box-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
