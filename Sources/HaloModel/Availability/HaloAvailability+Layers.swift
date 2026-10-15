// Availability/HaloAvailability+Layers.swift: whether the Layer commands can
// act now. Layer > New and picking a layer are shipped and answer from state
// only; Duplicate, Rename, Delete, reorder and clearing the selection are not
// built yet (#770), and `layer-panel` replaces this file whole when they
// are, keeping those answers. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func layersHelp(_ command: HaloCommand) -> String? {
        switch command {
        case .newLayer:
            return canAddLayer ? nil : HaloEditError.noComposition.message
        case .selectLayer(.some(let id)):
            guard let comp = selectedComposition else { return HaloEditError.noComposition.message }
            return comp.layers.contains { $0.id == id } ? nil : HaloEditError.unknownLayer(id).message
        default:
            return "Not built yet (#770)."
        }
    }
}
