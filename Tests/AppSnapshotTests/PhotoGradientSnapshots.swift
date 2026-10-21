// PhotoGradientSnapshots.swift: the Gradient tool's screens (gradient-fill
// PG-2, PG-5) on a 640 x 480 image. `options` writes
// photo-gradient-options-light/dark.png: the Gradient tool picked, Tool
// Options showing its hint over SuiteUI's GradientEditor on the default
// black-to-white linear fill, with no angle row (the drag sets the line).
// `radialOptions` writes photo-gradient-options-radial-light/dark.png, the
// editor switched to Radial.
// `drag` writes photo-gradient-drag-light/dark.png: the top half marqueed and
// a gradient drag under way from its top to its bottom, the line on the
// canvas (PG-6's overlay). `done` writes photo-gradient-done-light/dark.png:
// the same drag released, the gradient drawn inside the selection as one
// "Gradient" step. macOS only.
import CoreRaster
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoGradientSnapshots {
    /// A 640 x 480 sky (blue at the top, pale at the bottom) with the Gradient tool picked.
    private func opened() throws -> PhotoWorkspace {
        let (w, h) = (640, 480)
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                bytes[i] = UInt8(40 + y * 160 / h)
                bytes[i + 1] = UInt8(90 + y * 130 / h)
                bytes[i + 2] = UInt8(200 + x * 40 / w)
            }
        }
        var model = PhotoWorkspace()
        try model.open(rgba8: bytes, width: w, height: h, name: "sky.png")
        model.selectTool(.gradient)
        return model
    }

    /// `opened()` with its top half marqueed, the Gradient tool picked again, and a drag from the
    /// selection's top to its bottom, released when `release` is true.
    private func dragged(release: Bool) throws -> PhotoWorkspace {
        var model = try opened()
        model.selectTool(.marquee)
        model.drag(from: Mask.Point(x: 0, y: 0), to: Mask.Point(x: 0, y: 0))
        model.drag(from: Mask.Point(x: 0, y: 0), to: Mask.Point(x: 640, y: 240))
        model.endDrag()
        model.selectTool(.gradient)
        let (top, bottom) = (Mask.Point(x: 320, y: 20), Mask.Point(x: 320, y: 220))
        model.drag(from: top, to: top)
        model.drag(from: top, to: bottom)
        if release { model.endDrag() }
        return model
    }

    /// Writes photo-gradient-<state>-light.png and -dark.png.
    private func shoot(_ state: String, _ model: PhotoWorkspace) throws {
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "photo-gradient-\(state)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func options() throws {
        let model = try opened()
        #expect(model.tool == .gradient)
        #expect(model.toolOptions.gradient == ToolOptions.defaultGradient)
        #expect(PhotoFillToolOptions.types == [.linear, .radial])
        #expect(!PhotoFillToolOptions.showsAngle)
        try shoot("options", model)
    }

    @Test func radialOptions() throws {
        var model = try opened()
        model.runGradientOption(.type(.radial))
        guard case .radial = model.toolOptions.gradient else {
            Issue.record("the type switch left the gradient \(model.toolOptions.gradient)")
            return
        }
        try shoot("options-radial", model)
    }

    @Test func drag() throws {
        let model = try dragged(release: false)
        #expect(model.isDragging, "the gradient drag ended before its release")
        #expect(model.selection != nil, "the marquee left no selection")
        try shoot("drag", model)
    }

    @Test func done() throws {
        let model = try dragged(release: true)
        #expect(!model.isDragging)
        #expect(model.undoActionName == "Undo Gradient", "the release left no Gradient step")
        try shoot("done", model)
    }
}
