// PhotoPenSnapshots.swift: the Pen on a 640 x 480 white image (#5072). `drawing` writes
// photo-pen-drawing-light/dark.png: the Pen picked, its hint in Tool Options, a closed path in edit
// with one anchor selected, and an open draft of two points beside it, drawn by SuiteUI's
// PathEditOverlay through PhotoPenOverlay. macOS only.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoPenSnapshots {
    @Test func drawing() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        model.selectTool(.pen)
        for intent: PathIntent in [.penAdd(Point(x: 80, y: 80), handleOut: nil), .penAdd(Point(x: 300, y: 90), handleOut: Point(x: 360, y: 160)),
                                   .penAdd(Point(x: 160, y: 300), handleOut: nil), .close,
                                   .select(anchors: [AnchorRef(contour: 0, index: 1)], rect: nil, extend: false),
                                   .penAdd(Point(x: 420, y: 320), handleOut: nil), .penAdd(Point(x: 560, y: 400), handleOut: nil)] {
            model.runPath(intent)
        }
        #expect(model.paths.count == 1)
        #expect(model.penDraft?.contour.anchors.count == 2)
        let tiles = try photoTiles(model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoEditor(model: model, tiles: tiles, renderMilliseconds: 8, zoom: 1),
                name: "photo-pen-drawing-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
