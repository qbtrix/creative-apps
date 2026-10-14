// PhotoCloneSnapshots.swift: the Photo window with the Clone tool selected
// (#647): the rail shows Clone picked, the canvas marks the sampled source
// over an orange square, a clone stroke has copied part of the square to the
// right, and Tool Options shows the hint with the brush's size, hardness and
// opacity. Writes photo-clone-light.png and photo-clone-dark.png. macOS only.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoCloneSnapshots {
    @Test func cloneToolWithSource() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        model.setToolOption(.color(red: 240, green: 140, blue: 40))
        model.selectTool(.marquee)
        model.drag(from: Mask.Point(x: 120, y: 160), to: Mask.Point(x: 260, y: 300))
        model.endDrag()
        model.fillSelection()
        model.deselect()
        model.selectTool(.clone)
        model.setToolOption(.size(60))
        model.setCloneSource(at: Mask.Point(x: 190, y: 230))
        model.drag(from: Mask.Point(x: 420, y: 200), to: Mask.Point(x: 420, y: 200))
        model.drag(from: Mask.Point(x: 420, y: 200), to: Mask.Point(x: 460, y: 260))
        model.endDrag()
        let image = try photoImage(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, image: image, renderMilliseconds: 8, zoom: 1),
                name: "photo-clone-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
