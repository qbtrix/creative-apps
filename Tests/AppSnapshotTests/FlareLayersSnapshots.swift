// FlareLayersSnapshots.swift: Flare's SCENES and LAYERS sidebar rows
// (layers-files LF-1): SCENES as SidebarRows under its title and add button,
// since the sidebar List does not render here, then LAYERS as the window's
// own FlareLayersList, the shared LayerTreeList (AL-f3), embedded. A new
// document with three layers, one hidden and one locked; `bounce` with Shadow
// hidden (Background is locked); two scenes; and `empty`, whose LAYERS has no
// rows and its New Layer button. `rowsFromTree` checks LAYERS is the
// kernel's `layerRows` (adopt-kernel-layers AL-f2); hidden and locked rows
// read dimmed (LF-1d) and `rowMenus` checks each row's context menu (LF-2).
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
        // The hidden and the locked row read dimmed; the third doesn't (LF-1d).
        let dimmed = model.layerRows.filter { LayerTreeOptions(dimsLocked: true).dims($0) }.map(\.id)
        #expect(Set(dimmed) == ["layer-1", "layer-2"])
        #expect(model.layerRows.filter { LayerTreeOptions().dims($0) }.map(\.id) == ["layer-1"])
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

    /// Each row's context menu (LF-2): a layer's four items act, and the last scene's Delete is off and says why.
    @Test func rowMenus() {
        let model = fixture("bounce")
        let layer = FlareRowMenu.actions(model.layerRowMenu("shadow"), perform: { _ in })
        #expect(layer.map(\.title) == ["Hide Layer", "Lock Layer", "Duplicate Layer", "Delete Layer"])
        #expect(layer.allSatisfy { $0.unavailableHelp == nil })
        let scene = FlareRowMenu.actions(model.sceneRowMenu("scene-1"), perform: { _ in })
        #expect(scene.map(\.title) == ["Delete Scene"])
        #expect(scene.first?.unavailableHelp == "An animation needs at least one scene.")
    }

    @Test func emptyLayers() throws {
        let model = fixture("empty")
        #expect(model.layers.isEmpty && model.selectedScene != nil)
        try snapshot(LayersRows(model: model), name: "flare-sidebar-empty", scheme: .light)
    }

    @Test func rowsFromTree() {
        var model = fixture("bounce")
        model.toggleLayerFlag("shadow", .visible)
        #expect(model.layerRows.map(\.name) == ["Ball", "Shadow", "Background"])
        #expect(SidebarSection.flareScenes(model, perform: { _ in }).items.map(\.title) == ["Scene 1"])
        // The shared list's `.sidebar` toggles keep the ids the journeys click: FlareLayerFlag's raw values.
        let shadow = model.layerRows.first { $0.id == "shadow" }
        let eye = shadow.map { LayerTreeNaming.sidebar.visibility($0) }
        let lock = shadow.map { LayerTreeNaming.sidebar.lock($0) }
        #expect(eye?.title == "Show Layer" && eye?.isOn == false && lock?.title == "Lock Layer")
        #expect(eye.map { LayerTreeNaming.sidebar.identifier(of: $0, in: "shadow") } == "suite.sidebar.shadow.visible")
        #expect(lock.map { LayerTreeNaming.sidebar.identifier(of: $0, in: "shadow") } == "suite.sidebar.shadow.locked")
    }

    private func fixture(_ name: String) -> FlareWorkspace {
        FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", name]))
    }
}

private struct LayersRows: View {
    let model: FlareWorkspace
    var body: some View {
        let scenes = SidebarSection.flareScenes(model, perform: { _ in })
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack {
                Text(scenes.title).font(SuiteFont.headline)
                Spacer(minLength: SuiteSpacing.s)
                if let add = scenes.addAction {
                    Label(add.title, systemImage: add.systemImage).labelStyle(.iconOnly)
                }
            }
            ForEach(scenes.items) { SidebarRow($0) }
            FlareLayersList(model: model, embedded: true, perform: { _ in })
        }
        .padding(SuiteSpacing.m)
        .frame(width: SuiteSize.sidebarWidth.ideal, alignment: .leading)
        .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
    }
}
