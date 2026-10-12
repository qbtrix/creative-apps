// PhotoLayersSnapshots.swift: Photo's Layers section with three layers, the
// middle one hidden, drawn as SidebarRows in a VStack (the sidebar List does
// not render here), in Light and Dark. Writes photo-layers-light.png and
// photo-layers-dark.png. macOS only.
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor
@Suite struct PhotoLayersSnapshots {
    @Test func layers() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 1920, height: 1080)
        model.addLayer()
        model.addLayer()
        model.toggleVisibility("layer-2")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(LayersRows(model: model), name: "photo-layers-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct LayersRows: View {
    let model: PhotoWorkspace
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            Text("Layers").font(SuiteFont.headline)
            ForEach(PhotoLayerItems.items(model.layers)) { SidebarRow($0) }
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal, alignment: .leading)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
    }
}
