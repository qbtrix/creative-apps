// PhotoCloneHealSnapshots.swift: Photo's Tool Options section with the Heal
// tool selected (#422): the Option-click hint over the brush's size, hardness
// and opacity. Light and Dark. Writes photo-clone-heal-light.png and
// photo-clone-heal-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoCloneHealSnapshots {
    @Test func healOptions() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 640, height: 480)
        model.selectTool(.heal)
        model.setToolOption(.size(32))
        for scheme in [ColorScheme.light, .dark] {
            let view = ToolOptionsSection(model: model, perform: { _ in })
                .padding(SuiteSpacing.m)
                .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                .padding(SuiteSpacing.xxl)
            try snapshot(view, name: "photo-clone-heal-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
