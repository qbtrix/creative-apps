// FakeOnion.swift: OnionSkinning by hand (docs/blueprints/flare.md, 6.3) until FlareCore has onion frames (LC-9).
// Ghosts are `FakeStage`'s draw list at the frames before and after the playhead, kept to the scene's frames and to
// the asked-for layers (every layer when none are named). The ghost `n` frames away has opacity falloff^n, so each
// step out is dimmer by exactly the falloff. Nothing shows while onion skin is off. The motion path is the layer's
// origin at every frame of its owner. With `unavailable` set, both are empty.
import FlareCore

public struct FakeOnion: OnionSkinning {
    /// Why this member is off; nil when it works.
    public var unavailable: String?
    public init(unavailable: String? = nil) { self.unavailable = unavailable }

    public func ghosts(_ document: Document, sceneID: String, layerIDs: [String], frame: Int,
                       settings: OnionSettings) -> [Ghost] {
        guard unavailable == nil, settings.isOn,
              let scene = document.scenes.first(where: { $0.id == sceneID }) else { return [] }
        let falloff = settings.falloff.isFinite ? min(max(settings.falloff, 0), 1) : 0
        let lastFrame = scene.durationFrames - 1
        let stage = FakeStage()
        func ghost(_ distance: Int, _ side: Ghost.Side) -> Ghost? {
            let at = side == .before ? frame - distance : frame + distance
            guard at >= 0, at <= lastFrame else { return nil }
            let items = stage.drawList(document, sceneID: sceneID, frame: at, editing: nil).items
                .filter { layerIDs.isEmpty || layerIDs.contains($0.address.layerID) }
            let opacity = (0..<distance).reduce(1.0) { value, _ in value * falloff }
            return Ghost(frame: at, side: side, opacity: opacity, items: items)
        }
        // Farthest first, so nearer ghosts draw over farther ones.
        return stride(from: settings.before, through: 1, by: -1).compactMap { ghost($0, .before) }
            + stride(from: settings.after, through: 1, by: -1).compactMap { ghost($0, .after) }
    }

    public func motionPath(_ document: Document, owner: LayerOwner, layerID: String) -> [Point] {
        guard unavailable == nil, let layer = document.layers(of: owner)?.first(where: { $0.id == layerID }) else { return [] }
        let frames = switch owner {
        case .scene(let id): document.scenes.first { $0.id == id }?.durationFrames ?? 0
        case .symbol(let id): document.symbols.first { $0.id == id }?.durationFrames ?? 0
        }
        return (0..<max(frames, 0)).map { layer.placement(at: Double($0)).transform.matrix.apply(Point(x: 0, y: 0)) }
    }
}
