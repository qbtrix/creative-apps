// PhotoTransformSnapshots.swift (transform PT-7): the Photo window (PhotoEditor)
// with Edit > Free Transform up, in the packet's two transform screens
// (docs/blueprints/photo/features/transform.md, Screens and states). Both run
// on the `sample` fixture (800 x 600) with a 400 x 200 marquee over its middle
// and the Move tool, so the draft's box is the selection's part of Background.
// `rows`: the draft just begun, its handles on the box and the inspector's
// transform rows (X 200, Y 200, W 400, H 200, Rotation 0°) over Apply
// Transform and Cancel; it holds on PT-1's stubs, where Begin works. `turned`:
// the draft turned 15° through `setTransform`, the handles and the Rotation
// row turned with it; it waits on PT-5, which builds the draft's edits (on the
// stubs every edit refuses). Canvas Size's sheet has its own screens in
// PhotoCanvasSizeSheetTests (PT-3). Writes photo-free-transform-rows-light/
// -dark.png and photo-free-transform-light/-dark.png. macOS only.
import CoreRaster
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoTransformSnapshots {
    /// The sample picture, a 400 x 200 marquee from (200, 200), the Move tool, and Free Transform begun.
    private func transforming() throws -> PhotoWorkspace {
        var model = try PhotoWorkspace.fixture(.sample)
        model.selectTool(.marquee)
        model.drag(from: Mask.Point(x: 200, y: 200), to: Mask.Point(x: 200, y: 200))
        model.drag(from: Mask.Point(x: 200, y: 200), to: Mask.Point(x: 600, y: 400))
        model.endDrag()
        model.selectTool(.move)
        try model.beginTransform()
        return model
    }

    private func shoot(_ name: String, _ model: PhotoWorkspace) throws {
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func rows() throws {
        let model = try transforming()
        #expect(model.transformDraft != nil, "Free Transform didn't start")
        #expect(model.transformHelp == nil, "the rows are disabled: \(model.transformHelp ?? "")")
        let box = try #require(model.transformSelection)
        #expect(box.box == Rect(minX: 200, minY: 200, maxX: 600, maxY: 400), "the draft's box is \(box.box)")
        #expect(box.degrees == 0)
        try shoot("photo-free-transform-rows", model)
    }

    @Test(.disabled("waits on PT-5")) func turned() throws {
        var model = try transforming()
        let box = try #require(model.transformSelection)
        try model.setTransform(TransformRules.rotated(box, by: 15), name: "Rotate", drag: nil)
        let after = try #require(model.transformSelection)
        #expect(abs(after.degrees - 15) < 0.001, "the draft turned to \(after.degrees)°, not 15°")
        #expect(model.transformDraft != nil, "the turn ended Free Transform")
        try shoot("photo-free-transform", model)
    }
}
