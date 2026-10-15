// HaloWindow+Layers.swift: the layers area's routes and hook. Layer > New
// and picking a layer are shipped and call the Model; Duplicate, Rename…,
// Delete, reorder and clearing the selection are not built yet, so those do
// nothing. layer-panel (#770) replaces this file whole, keeping the shipped
// routes; its `layersScene(_:)` presents Rename Layer… from `request`.
import HaloModel
import SwiftUI

extension HaloWindow {
    func layersPerform(_ command: HaloCommand) {
        switch command {
        case .newLayer(let kind): model.newLayer(kind)
        case .selectLayer(.some(let id)): model.selectLayer(id)
        default: break
        }
    }

    func layersScene(_ content: some View) -> some View { content }
}
