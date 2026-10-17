// FlareLayerItems.swift: sidebar items for Flare's SCENES and LAYERS sections
// (layers-files LF-1). Each section's add button sends its `.layers` intent
// (New Scene, New Layer) through `perform`, and is absent while it can't act.
// A layer row carries an eye and a lock toggle whose ids are FlareLayerFlag
// raw values, so FlareWindow routes a click straight to toggleLayerFlag. A
// hidden or locked layer's row should draw dimmed (the Model's
// layerRowIsDimmed); SidebarItem has no dimmed state yet (needs-ui #146), so
// for now the eye and lock toggles alone show it.
import FlareCore
import FlareModel
import SuiteUI

extension SidebarItem {
    init(scene: FlareCore.Scene) {
        self.init(id: scene.id, title: scene.name, systemImage: "film")
    }

    init(layer: FlareCore.Layer) {
        self.init(
            id: layer.id, title: layer.name, systemImage: "square.3.layers.3d",
            toggles: [
                SidebarToggle(
                    id: FlareLayerFlag.visible.rawValue, title: layer.isVisible ? "Hide Layer" : "Show Layer",
                    onSymbol: "eye", offSymbol: "eye.slash", isOn: layer.isVisible),
                SidebarToggle(
                    id: FlareLayerFlag.locked.rawValue, title: layer.isLocked ? "Unlock Layer" : "Lock Layer",
                    onSymbol: "lock.fill", offSymbol: "lock.open", isOn: layer.isLocked),
            ])
    }
}

extension SidebarSection {
    /// The SCENES and LAYERS sections. New Scene shows while an animation is open, New Layer while a scene is
    /// selected; each sends its intent through `perform`.
    static func flare(_ model: FlareWorkspace, perform: @escaping @MainActor (FlareIntent.Layers) -> Void) -> [SidebarSection] {
        [
            SidebarSection(
                id: "scenes", title: "Scenes", items: model.scenes.map { SidebarItem(scene: $0) },
                addAction: model.document == nil
                    ? nil : ToolbarAction("New Scene", systemImage: "plus") { perform(.addScene) }),
            SidebarSection(
                id: "layers", title: "Layers", items: model.layers.map { SidebarItem(layer: $0) },
                addAction: model.selectedScene == nil
                    ? nil : ToolbarAction("New Layer", systemImage: "plus") { perform(.addLayer) }),
        ]
    }
}
