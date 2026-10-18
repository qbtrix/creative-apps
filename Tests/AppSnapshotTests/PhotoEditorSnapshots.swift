// PhotoEditorSnapshots.swift: the Photo window (PhotoEditor) in each state
// its core loop reaches: an opened photo, layers composited, a brush and an
// eraser stroke, a marquee selection, a pending crop, a moved layer, exposure
// +1, layers in the sidebar, the export sheet and a refusal in the status line
// (photo-status-message-dark.png only); the rail's tool help is checked here
// too. Each other state writes
// photo-<state>-light.png and photo-<state>-dark.png. The canvas picture is rendered the way the window renders
// it (the workspace's tiles on their layers).
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

/// The workspace's picture as the canvas shows it: its tile layers.
@MainActor
func photoTiles(_ model: PhotoWorkspace) throws -> CanvasTiles? {
    try CanvasTiles.complete(model)
}

@MainActor
@Suite struct PhotoEditorSnapshots {
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

    private func drag(_ model: inout PhotoWorkspace, _ tool: PhotoTool, _ a: (Double, Double), _ b: (Double, Double)) {
        model.selectTool(tool)
        model.drag(from: Mask.Point(x: a.0, y: a.1), to: Mask.Point(x: a.0, y: a.1))
        model.drag(from: Mask.Point(x: a.0, y: a.1), to: Mask.Point(x: b.0, y: b.1))
        model.endDrag()
    }

    private func shoot(_ state: String, _ model: PhotoWorkspace) throws {
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "photo-\(state)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func openedPhoto() throws {
        try shoot("opened", try opened())
    }

    @Test func layersComposite() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        model.addLayer()
        model.setToolOption(.color(red: 255, green: 0, blue: 0))
        drag(&model, .marquee, (120, 90), (520, 390))
        model.fillSelection()
        model.deselect()
        let red = try #require(model.selectedLayerID)
        model.setBlendMode(red, .multiply)
        model.setOpacity(red, percent: 50)
        try shoot("layer-composite", model)
    }

    @Test func brushAndEraserStrokes() throws {
        var model = try opened()
        model.setToolOption(.size(24))
        drag(&model, .brush, (60, 60), (580, 420))
        try shoot("brush-stroke", model)
        model.selectTool(.eraser)
        model.setToolOption(.size(24))
        drag(&model, .eraser, (60, 420), (580, 60))
        try shoot("eraser-stroke", model)
    }

    @Test func selectionAndPendingCrop() throws {
        var model = try opened()
        drag(&model, .marquee, (80, 80), (300, 240))
        try shoot("selection", model)
        drag(&model, .crop, (40, 40), (600, 400))
        try shoot("crop-pending", model)
    }

    @Test func movedLayer() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        model.addLayer()
        model.setToolOption(.color(red: 220, green: 30, blue: 30))
        drag(&model, .marquee, (80, 140), (280, 340))
        model.fillSelection()
        model.deselect()
        drag(&model, .move, (180, 240), (300, 240))
        try shoot("move", model)
    }

    @Test func exposurePlusOne() throws {
        var model = try opened()
        model.adjust(.exposure(1))
        try shoot("exposure-plus1", model)
    }

    /// A brush drag on the `layered` fixture's adjustment layer refuses, and
    /// the status line shows why, left of the pills.
    @Test func statusMessage() throws {
        var model = try PhotoWorkspace.fixture(.layered)
        let curves = try #require(model.layers.first { $0.name == "Curves 1" })
        model.selectLayer(curves.id)
        drag(&model, .brush, (200, 200), (300, 260))
        #expect(model.statusMessage == "Select an image layer in the sidebar to paint on.")
        try snapshot(
            PhotoEditor(model: model, tiles: try photoTiles(model), renderMilliseconds: 8, zoom: 1),
            name: "photo-status-message-dark", scheme: .dark)
    }

    /// The palette's Eyedropper carries the sampling service's help: disabled on
    /// `.live`, enabled on `.fake`.
    @Test func paletteEyedropperHelp() {
        let live = PhotoWorkspace(services: .live)
        #expect(PhotoPaletteTool(.eyedropper, in: live).unavailableHelp == live.toolHelp(.eyedropper))
        #expect(PhotoPaletteTool(.eyedropper, in: live).unavailableHelp == "Not built yet (PV-9).")
        #expect(PhotoPaletteTool(.eyedropper, in: PhotoWorkspace(services: .fake)).unavailableHelp == nil)
        #expect(PhotoPaletteTool.palette(live).map(\.tool) == PhotoTool.allCases)
    }

    @Test func exportSheet() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                ExportSheet(format: .jpeg, quality: 0.9).frame(maxWidth: .infinity, maxHeight: .infinity),
                name: "photo-export-sheet-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
