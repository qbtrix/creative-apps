// PhotoLayerItems.swift: how a PhotoLayer appears in the sidebar's Layers
// section: a SuiteUI SidebarItem with one eye toggle for visibility. The
// toggle's id is `PhotoLayerItems.visibility`; PhotoWindow routes it to
// PhotoWorkspace.toggleVisibility.
import PhotoModel
import SuiteUI

enum PhotoLayerItems {
    static let sectionID = "layers"
    static let visibility = "visible"

    /// One sidebar row per layer, top first, as the workspace orders them.
    static func items(_ layers: [PhotoLayer]) -> [SidebarItem] {
        layers.map { layer in
            SidebarItem(
                id: layer.id, title: layer.name, systemImage: "square.2.layers.3d",
                toggles: [
                    SidebarToggle(
                        id: visibility, title: layer.isVisible ? "Hide Layer" : "Show Layer",
                        onSymbol: "eye", offSymbol: "eye.slash", isOn: layer.isVisible)
                ])
        }
    }
}
