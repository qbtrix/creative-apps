// PhotoTransformSnapshots.swift: Free Transform and Canvas Size (transform
// PT-7) on the `layered` fixture (800 x 600, Paint selected) with the Move
// tool picked. `draftUp`: Edit > Free Transform just begun, SuiteUI's handles
// on Paint's box and the transform rows over Apply Transform and Cancel in the
// inspector; writes photo-free-transform-light/dark.png. `draftTurned` (waits
// on PT-5): the draft scaled and turned 15 degrees, the handles turned with it;
// writes photo-free-transform-turned-light/dark.png. `canvasSizeAnchored`: the
// Canvas Size sheet over the window in absolute sizes, 1000 x 800 about the
// bottom-right anchor; writes photo-canvas-size-anchor-light/dark.png (PT-3's
// PhotoCanvasSizeSheetTests has the relative and crop states). macOS only.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoTransformSnapshots {
    /// The layered fixture on the fakes, Move picked.
    private func opened() throws -> PhotoWorkspace {
        var model = try PhotoWorkspace.fixture(.layered)
        model.selectTool(.move)
        return model
    }

    @Test func draftUp() throws {
        var model = try opened()
        try model.beginTransform()
        #expect(model.transformDraft != nil && model.transformHelp == nil)
        try snapshots(model, name: "photo-free-transform")
    }

    @Test(.disabled("waits on PT-5")) func draftTurned() throws {
        var model = try opened()
        try model.beginTransform()
        var turned = try #require(model.transformSelection)
        turned.box = Rect(minX: turned.box.minX + 40, minY: turned.box.minY + 30,
                          maxX: turned.box.maxX - 80, maxY: turned.box.maxY - 60)
        turned.degrees = 15
        try model.setTransform(turned, name: "Free Transform", drag: nil)
        #expect(model.transformSelection?.degrees == 15)
        try snapshots(model, name: "photo-free-transform-turned")
    }

    @Test func canvasSizeAnchored() throws {
        let model = try opened()
        let size = try #require(model.canvas)
        let draft = CanvasSizeDraft(old: size).with(width: 1000).with(height: 800).with(anchor: .bottomRight)
        #expect(CanvasSizeSheet(draft: draft).cropNote == nil)
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            let view = ZStack(alignment: .top) {
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1)
                CanvasSizeSheet(draft: draft)
                    .background(SuiteColor.panel, in: .rect(cornerRadius: SuiteRadius.large))
                    .padding(.top, SuiteSpacing.xxl)
            }
            try snapshot(view, name: "photo-canvas-size-anchor-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// The window at 100 % zoom, Light and Dark, as `name`-light/dark.png.
    private func snapshots(_ model: PhotoWorkspace, name: String) throws {
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
