// PhotoCloneSnapshots.swift: Photo's tool options bar with the Clone tool
// selected (#647): the Option-click hint over the brush's size, hardness and
// opacity. Light and Dark. Writes photo-clone-options-light.png and
// photo-clone-options-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoCloneSnapshots {
    @Test func cloneOptions() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        model.selectTool(.clone)
        model.setToolOption(.size(32))
        for scheme in [ColorScheme.light, .dark] {
            // The bar as the window draws it over the canvas, at the window's width.
            let view = PhotoToolOptionsBar(model: model, perform: { _ in })
                .frame(maxHeight: .infinity, alignment: .top)
            try snapshot(view, name: "photo-clone-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
