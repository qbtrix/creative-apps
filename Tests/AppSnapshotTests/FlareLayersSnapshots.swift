// FlareLayersSnapshots.swift: Flare's Scenes and Layers rows for a scene with
// three layers, one hidden and one locked, as SidebarRows in a VStack, since
// the sidebar List does not render here.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareLayersSnapshots {
    @Test func layers() throws {
        var model = FlareWorkspace()
        model.newDocument()
        for _ in 0..<3 { model.addLayer() }
        model.toggleLayerFlag("layer-1", .visible)
        model.toggleLayerFlag("layer-2", .locked)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(LayersRows(model: model), name: "flare-layers-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct LayersRows: View {
    let model: FlareWorkspace
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ForEach(SidebarSection.flare(model, onAddLayer: {})) { section in
                Text(section.title).font(SuiteFont.headline)
                ForEach(section.items) { SidebarRow($0, onToggle: { _ in }) }
            }
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal, alignment: .leading)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
    }
}
