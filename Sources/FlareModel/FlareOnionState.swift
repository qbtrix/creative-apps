// FlareOnionState.swift: onion skin and the motion path (docs/blueprints/flare.md, sections 2 and 3). Both are
// preferences: they survive opening another file and never touch the document or undo. Ghosts and the path come
// from `services.onion`; the stage overlay reads them.
import FlareCore

extension FlareWorkspace {
    /// How many frames before or after the popover can ask for.
    public static let onionCounts = 0...10

    /// Turns onion skin on or off.
    public mutating func toggleOnion() { onion.isOn.toggle() }
    /// Sets how many frames before or after the playhead show, clamped to `onionCounts`.
    public mutating func setOnionBefore(_ count: Int) { onion.before = min(max(count, 0), Self.onionCounts.upperBound) }
    public mutating func setOnionAfter(_ count: Int) { onion.after = min(max(count, 0), Self.onionCounts.upperBound) }

    /// Sets how much dimmer each step out is, clamped to 0...1; a value that is not a number is ignored.
    public mutating func setOnionFalloff(_ falloff: Double) {
        guard falloff.isFinite else { return }
        onion.falloff = min(max(falloff, 0), 1)
    }

    /// View > Motion Path.
    public mutating func toggleMotionPath() { showsMotionPath.toggle() }

    /// The ghosts around the playhead in the selected scene, every layer; empty while onion skin is off.
    public var ghosts: [Ghost] {
        guard onion.isOn, let document, let sceneID = selectedSceneID, editingSymbolID == nil else { return [] }
        return services.onion.ghosts(document, sceneID: sceneID, layerIDs: [], frame: currentFrame, settings: onion)
    }

    /// The one inspected layer's origin at every frame; empty while the path is hidden or not exactly one layer is.
    public var motionPath: [Point] {
        let layers = propertyLayerIDs
        guard showsMotionPath, let document, let owner = propertyOwner, layers.count == 1, let id = layers.first else { return [] }
        return services.onion.motionPath(document, owner: owner, layerID: id)
    }
}
