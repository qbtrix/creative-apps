// FlareEditOrder.swift: the Object menu's Bring Forward and Send Backward (docs/blueprints/flare/features/stage-edit.md,
// SE-4). Each moves the panel's selected layer one row through the same FlareCore ReorderLayer command moveLayer runs,
// as one named undo entry. A move that can't run gives its menu item's disabled reason in `orderHelp` and refuses
// with that text, changing nothing; the stage and layer selection survive the move.
import FlareCore

extension FlareWorkspace {
    /// Moves the selected layer one row up in the panel, over the layer above it, as one "Bring Forward" step.
    public mutating func bringForward() { moveSelectedLayer(forward: true) }

    /// Moves the selected layer one row down in the panel, under the layer below it, as one "Send Backward" step.
    public mutating func sendBackward() { moveSelectedLayer(forward: false) }

    /// Why Bring Forward (`forward`) or Send Backward can't run, as its menu item's tooltip; nil when it can.
    public func orderHelp(forward: Bool) -> String? {
        guard let ownerLayers else { return FlareLayerError.noDocument.message }
        guard let index = ownerLayers.firstIndex(where: { $0.id == selectedLayerID }) else {
            return "Select a layer first."
        }
        // ownerLayers is bottom first, so forward is the next index up.
        let neighbor = forward ? index + 1 : index - 1
        guard ownerLayers.indices.contains(neighbor) else {
            return forward ? "Already at the front." : "Already at the back."
        }
        let passed = ownerLayers[neighbor]
        return passed.isLocked ? "\(passed.name) is locked." : nil
    }

    /// Runs Bring Forward or Send Backward: the same command as `moveLayer(from:to:)`, in one named step.
    private mutating func moveSelectedLayer(forward: Bool) {
        if let reason = orderHelp(forward: forward) { return refuse(.refused(reason)) }
        guard let owner = propertyOwner, let ownerLayers,
              let index = ownerLayers.firstIndex(where: { $0.id == selectedLayerID }) else { return }
        let command = ReorderLayer(owner: owner, layerID: ownerLayers[index].id, toIndex: forward ? index + 1 : index - 1)
        applyGroup(forward ? "Bring Forward" : "Send Backward") { try $0.perform(command) }
    }
}
