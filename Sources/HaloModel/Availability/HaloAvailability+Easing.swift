// Availability/HaloAvailability+Easing.swift: whether Keyframe Easing, key
// picking and the EASING curve can act now (#428, EZ-5). Every one needs a
// composition. A lane click selects the layer it hits, so it needs nothing
// more; the rest need a selected layer. With those, the easing service may
// say why not, and then the commands that change easing need a picked key
// (EZ-2's `pickedKeys`), named for the span its row shows (#1454). Picking
// and clearing act whenever they can reach a layer. Linux-safe.

extension HaloProject {
    /// Nil when `command` can act now; otherwise why not.
    func easingHelp(_ command: HaloCommand) -> String? {
        guard selectedComposition != nil else { return HaloEditError.noComposition.message }
        if case .selectLaneKeys = command { return services.easing.unavailableHelp }
        guard selectedLayer != nil else { return HaloEditError.noLayerSelected.message }
        if let reason = services.easing.unavailableHelp { return reason }
        switch command {
        case .setEasing, .setCustomEasing, .moveEasingHandle, .endEasingDrag:
            return pickedKeys.isEmpty ? "Pick a span in the EASING list first." : nil
        default:
            return nil
        }
    }
}
