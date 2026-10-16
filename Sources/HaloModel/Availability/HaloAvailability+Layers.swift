// Availability/HaloAvailability+Layers.swift: whether the Layer commands can
// act now, answered from state only. New needs a composition; Duplicate,
// Rename…, Delete, Bring Forward and Send Backward need a selected layer, and
// the two moves are off at the end they would move past (the Model's moves do
// nothing there). Rename, move and pick act on a layer the composition has.
// Clearing the selection has no Model method, so it stays off with its
// reason. `layerMenuReasons` lists the Layer menu's top items as the menu
// shows them, for the journeys' hidden `halo.menu.reasons` readout (XCUITest
// reads a menu item's help tag as no text). Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func layersHelp(_ command: HaloCommand) -> String? {
        guard let comp = selectedComposition else { return HaloEditError.noComposition.message }
        switch command {
        case .newLayer:
            return nil
        case .duplicateLayer, .beginRenameLayer, .deleteLayer:
            return selectedLayer == nil ? HaloEditError.noLayerSelected.message : nil
        case .bringLayerForward:
            guard let id = selectedLayer?.id else { return HaloEditError.noLayerSelected.message }
            return comp.layers.first?.id == id ? "This layer is already at the top." : nil
        case .sendLayerBackward:
            guard let id = selectedLayer?.id else { return HaloEditError.noLayerSelected.message }
            return comp.layers.last?.id == id ? "This layer is already at the bottom." : nil
        case .renameLayer(let id, _), .moveLayer(let id, _), .selectLayer(.some(let id)):
            return comp.layers.contains { $0.id == id } ? nil : HaloEditError.unknownLayer(id).message
        case .selectLayer(.none):
            return "A layer stays selected until you pick another."
        default:
            return nil
        }
    }

    /// The Layer menu's top items, one line each: "Send Backward: This layer
    /// is already at the bottom." while one can't act, its title while it can.
    public var layerMenuReasons: String {
        let items: [HaloCommand] = [.duplicateLayer, .beginRenameLayer, .deleteLayer, .bringLayerForward, .sendLayerBackward]
        return items.map { command in unavailableHelp(for: command).map { "\(command.title): \($0)" } ?? command.title }
            .joined(separator: "\n")
    }
}
