// PhotoProInspectorSnapshots.swift: Photo's Adjust panel in the Pro density
// layout for a new 1920 × 1080 image with Background selected and every
// adjustment section open: the InspectorHeader with the Model's detail
// lines, Tool Options, then the flush, hairline-separated adjustment sections
// with Gamma as a ScrubField. Light and Dark. Writes
// photo-inspector-layer-light.png and photo-inspector-layer-dark.png.
// macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoProInspectorSnapshots {
    @Test func layerInspector() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 1920, height: 1080)
        #expect(model.selectedLayer?.name == "Background")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PhotoPanel(model: model, tab: .adjust)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "photo-inspector-layer-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
