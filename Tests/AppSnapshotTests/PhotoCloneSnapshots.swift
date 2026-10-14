// PhotoCloneSnapshots.swift: Photo's Tool Options section with the Clone tool
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
            let view = ToolOptionsSection(model: model, perform: { _ in })
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(view, name: "photo-clone-options-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
