// FlareSidebarHelp.swift: what the SCENES and LAYERS sidebar asks of the Model (layers-files LF-1, LF-2). The Remove
// reason for a scene row is `sceneRemoveHelp` (FlareScenes.swift), the one rule Remove Scene itself checks, so the
// tooltip and the refusal never disagree. A layer row reads dimmed when the layer is hidden or locked. Each row's
// context menu is a list of `FlareRowCommand`s: a layer's Hide, Lock, Duplicate and Delete, a scene's Delete, each
// sending the layers intent the sidebar's own controls send, with the reason it can't act as its help. A list
// update asks both for every shown row, so they find the layer in the owner's stored order, never `layers`, which
// rebuilds the kernel tree on each read.
import FlareCore

/// One row context menu item: its title and symbol, the layers intent it sends, and why it can't act (nil when it can).
public struct FlareRowCommand: Equatable, Sendable {
    public let title: String, systemImage: String
    public let intent: FlareIntent.Layers
    public let help: String?
}

extension FlareWorkspace {
    /// Why scene `id` can't be removed, as the Remove button's tooltip: "An animation needs at least one scene."
    /// for the last one, the machine rule for one a machine uses; nil when it can be removed.
    public func removeSceneHelp(_ id: String) -> String? { sceneRemoveHelp(id) }

    /// True when the edited owner's layer `id` is hidden or locked, so its sidebar row reads dimmed.
    public func layerRowIsDimmed(_ id: String) -> Bool {
        guard let layer = ownerLayers?.first(where: { $0.id == id }) else { return false }
        return !layer.isVisible || layer.isLocked
    }

    /// Layer `id`'s context menu: Hide or Show, Lock or Unlock, Duplicate, Delete; empty for an id that isn't a layer.
    /// Duplicate's reason is `editHelp(.duplicate)` with that layer picked: the shapes service's, when it has one.
    public func layerRowMenu(_ id: String) -> [FlareRowCommand] {
        guard let layer = ownerLayers?.first(where: { $0.id == id }) else { return [] }
        return [
            FlareRowCommand(title: layer.isVisible ? "Hide Layer" : "Show Layer",
                            systemImage: layer.isVisible ? "eye.slash" : "eye",
                            intent: .toggle(id: id, flag: FlareLayerFlag.visible.rawValue), help: nil),
            FlareRowCommand(title: layer.isLocked ? "Unlock Layer" : "Lock Layer",
                            systemImage: layer.isLocked ? "lock.open" : "lock",
                            intent: .toggle(id: id, flag: FlareLayerFlag.locked.rawValue), help: nil),
            FlareRowCommand(title: "Duplicate Layer", systemImage: "plus.square.on.square",
                            intent: .duplicate(id: id), help: services.shapes.unavailableHelp(for: .select)),
            FlareRowCommand(title: "Delete Layer", systemImage: "trash", intent: .remove(id: id), help: nil),
        ]
    }

    /// Scene `id`'s context menu: Delete, off with `removeSceneHelp` on the last scene; empty for an id that isn't a scene.
    public func sceneRowMenu(_ id: String) -> [FlareRowCommand] {
        guard scenes.contains(where: { $0.id == id }) else { return [] }
        return [FlareRowCommand(title: "Delete Scene", systemImage: "trash", intent: .remove(id: id), help: removeSceneHelp(id))]
    }

    /// Selects layer `id` and duplicates it above itself as one "Duplicate" step: the row menu's Duplicate Layer.
    public mutating func duplicateLayer(_ id: String) {
        selectItem(id)
        duplicate()
    }
}
