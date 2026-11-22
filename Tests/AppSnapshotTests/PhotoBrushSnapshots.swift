// PhotoBrushSnapshots.swift: Photo's tool options bar with the brush
// selected (#26): size, hardness, color and opacity, each away from its
// default. Light and Dark. Writes photo-brush-options-light.png and
// photo-brush-options-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoBrushSnapshots {
    @Test func brushOptions() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        model.selectTool(.brush)
        model.setToolOption(.size(48))
        model.setToolOption(.hardness(percent: 60))
        model.setToolOption(.opacity(percent: 80))
        model.setToolOption(.color(red: 220, green: 30, blue: 30))
        for scheme in [ColorScheme.light, .dark] {
            // The bar as the window draws it over the canvas, at the window's width.
            let view = PhotoToolOptionsBar(model: model, perform: { _ in })
                .frame(maxHeight: .infinity, alignment: .top)
            try snapshot(view, name: "photo-brush-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
