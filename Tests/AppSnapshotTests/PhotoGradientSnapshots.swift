// PhotoGradientSnapshots.swift: the Gradient tool's screens (gradient-fill
// PG-2, PG-5) on a 640 x 480 image. `options` writes
// photo-gradient-options-light/dark.png: the Gradient tool picked, Tool
// Options showing its hint over SuiteUI's GradientEditor on the default
// black-to-white linear fill, with no angle row (the drag sets the line).
// macOS only.
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

    @Test func options() throws {
        let model = try opened()
        #expect(model.tool == .gradient)
        #expect(model.toolOptions.gradient == ToolOptions.defaultGradient)
        #expect(PhotoFillToolOptions.types == [.linear, .radial])
        #expect(!PhotoFillToolOptions.showsAngle)
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "photo-gradient-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
