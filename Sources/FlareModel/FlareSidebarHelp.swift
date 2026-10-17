// FlareSidebarHelp.swift: what the SCENES and LAYERS sidebar asks of the Model (layers-files LF-1). The Remove
// reason for a scene row is `sceneRemoveHelp` (FlareScenes.swift), the one rule Remove Scene itself checks, so the
// tooltip and the refusal never disagree. A layer row reads dimmed when the layer is hidden or locked; SidebarItem
// has no dimmed state yet (needs-ui #146), so only the Model answers it for now.
import FlareCore

extension FlareWorkspace {
    /// Why scene `id` can't be removed, as the Remove button's tooltip: "An animation needs at least one scene."
    /// for the last one, the machine rule for one a machine uses; nil when it can be removed.
    public func removeSceneHelp(_ id: String) -> String? { sceneRemoveHelp(id) }

    /// True when the edited owner's layer `id` is hidden or locked, so its sidebar row reads dimmed.
    public func layerRowIsDimmed(_ id: String) -> Bool {
        guard let layer = layers.first(where: { $0.id == id }) else { return false }
        return !layer.isVisible || layer.isLocked
    }
}
