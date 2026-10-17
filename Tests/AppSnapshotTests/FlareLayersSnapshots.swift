// FlareLayersSnapshots.swift: Flare's SCENES and LAYERS sidebar rows
// (layers-files LF-1) as SidebarRows in a VStack under each section's title
// and add button, since the sidebar List does not render here. A new
// document with three layers, one hidden and one locked; `bounce` with Shadow
// hidden (Background is locked); two scenes; and `empty`, whose LAYERS has no
// rows and its New Layer button.
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

    @Test func bounceWithShadowHidden() throws {
        var model = fixture("bounce")
        model.toggleLayerFlag("shadow", .visible)
        #expect(model.layerRowIsDimmed("shadow") && model.layerRowIsDimmed("background") && !model.layerRowIsDimmed("ball"))
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(LayersRows(model: model), name: "flare-sidebar-bounce-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func twoScenes() throws {
        var model = fixture("bounce")
        model.addScene()
        #expect(model.scenes.count == 2)
        try snapshot(LayersRows(model: model), name: "flare-sidebar-scenes", scheme: .light)
    }

    @Test func emptyLayers() throws {
        let model = fixture("empty")
        #expect(model.layers.isEmpty && model.selectedScene != nil)
        try snapshot(LayersRows(model: model), name: "flare-sidebar-empty", scheme: .light)
    }

    private func fixture(_ name: String) -> FlareWorkspace {
        FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", name]))
    }
}

private struct LayersRows: View {
    let model: FlareWorkspace
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ForEach(SidebarSection.flare(model, perform: { _ in })) { section in
                HStack {
                    Text(section.title).font(SuiteFont.headline)
                    Spacer(minLength: SuiteSpacing.s)
                    if let add = section.addAction {
                        Label(add.title, systemImage: add.systemImage).labelStyle(.iconOnly)
                    }
                }
                ForEach(section.items) { SidebarRow($0, onToggle: { _ in }) }
            }
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal, alignment: .leading)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
    }
}
