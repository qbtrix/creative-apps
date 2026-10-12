// FlareLayerItems.swift: sidebar items for Flare's Scenes and Layers sections.
// A layer row carries an eye and a lock toggle whose ids are FlareLayerFlag
// raw values, so FlareWindow routes a click straight to toggleLayerFlag. A
// locked layer's name should draw dimmed; SidebarItem has no dimmed state yet
// (needs-ui #146), so for now the lock toggle alone shows it.
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
    /// The Scenes and Layers sections; the Layers section's add button calls `onAddLayer`.
    static func flare(_ model: FlareWorkspace, onAddLayer: @escaping @MainActor () -> Void) -> [SidebarSection] {
        [
            SidebarSection(id: "scenes", title: "Scenes", items: model.scenes.map { SidebarItem(scene: $0) }),
            SidebarSection(
                id: "layers", title: "Layers", items: model.layers.map { SidebarItem(layer: $0) },
                addAction: model.selectedScene == nil
                    ? nil : ToolbarAction("New Layer", systemImage: "plus", perform: onAddLayer)),
        ]
    }
}
