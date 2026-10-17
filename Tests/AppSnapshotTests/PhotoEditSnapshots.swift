// PhotoEditSnapshots.swift: the Photo window after a paste (photo-edit E-8):
// the sun marqueed, copied and pasted as "Pasted Layer" above Background and
// selected in the sidebar's layer list. Writes photo-pasted-layer-light.png
// and photo-pasted-layer-dark.png. Also checks the Layer menu's Duplicate
// Layer (Command-J), Merge Down (Command-E) and Flatten Image (no shortcut), and
// their reasons with one layer (QB-F4). macOS only.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoEditSnapshots {
    /// A 640 x 480 photo-like image: a sky gradient and a sun.
    private func opened() throws -> PhotoWorkspace {
        let (w, h) = (640, 480)
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let (dx, dy) = (Double(x - 420), Double(y - 200))
                let sun = dx * dx + dy * dy < 90 * 90
                bytes[i] = sun ? 250 : UInt8(40 + x * 180 / w)
                bytes[i + 1] = sun ? 190 : UInt8(80 + y * 120 / h)
                bytes[i + 2] = sun ? 60 : 200
            }
        }
        var model = PhotoWorkspace()
        try model.open(rgba8: bytes, width: w, height: h, name: "beach.png")
        return model
    }

    @Test func pastedLayer() throws {
        var model = try opened()
        model.selectTool(.marquee)
        model.drag(from: Mask.Point(x: 330, y: 110), to: Mask.Point(x: 330, y: 110))
        model.drag(from: Mask.Point(x: 330, y: 110), to: Mask.Point(x: 510, y: 290))
        model.endDrag()
        let taken = model.copySelection()
        let image = try #require(taken)
        model.deselect()
        model.paste(image, viewCenter: Mask.Point(x: 320, y: 240))
        #expect(model.layers.map(\.name) == ["Pasted Layer", "Background"])
        #expect(model.selectedLayer?.name == "Pasted Layer" && model.undoActionName == "Undo Paste")
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "photo-pasted-layer-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func layerCommandShortcuts() {
        #expect(PhotoLayerMenu.shortcut(.duplicateLayer) == KeyboardShortcut("j", modifiers: .command))
        #expect(PhotoLayerMenu.shortcut(.mergeDown) == KeyboardShortcut("e", modifiers: .command))
        #expect(PhotoLayerMenu.shortcut(.flattenImage) == nil)
    }

    @Test func oneLayerDisablesMergeAndFlattenWithTheirReasons() throws {
        let model = try opened()
        let menu = PhotoMenu(model: model, perform: { _ in })
        let empty = PhotoPasteboardState()
        #expect(menu.editHelp(.duplicateLayer, pasteboard: empty) == nil)
        #expect(menu.editHelp(.mergeDown, pasteboard: empty) == "There's no layer below to merge into.")
        #expect(menu.editHelp(.flattenImage, pasteboard: empty) == "The image already has one layer.")
        #expect(PhotoMenu().editHelp(.duplicateLayer, pasteboard: empty) == "Open an image first.")
    }
}
