// PhotoBrushSnapshots.swift: Photo's Tool Options section with the brush
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
            let view = ToolOptionsSection(model: model, perform: { _ in })
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(view, name: "photo-brush-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
