// LiveShapes+Box.swift: the live box gestures (docs/blueprints/flare/features/live-stage.md, task ST-8). `boxResult` is
// `BoxGestureMath` over `LiveStage`'s draw list, so live and fake share one box math. `commitBox` is one engine group,
// "Move", "Scale" or "Rotate", that writes each picked layer's x, y, scaleX, scaleY and rotation through
// `LiveProperties.setValue`, section 2's not-animated / animated rule: with two or more keys on the track, or auto-key
// on, the value is keyed at the playhead; otherwise the track's one key (frame 0 when there is none) takes it.
import FlareCore

extension LiveShapes {
    public func boxResult(_ gesture: BoxGesture, layers: [String], document: Document, sceneID: String,
                          frame: Int, box: Rect) -> [String: [String: Double]] {
        let list = LiveStage().drawList(document, sceneID: sceneID, frame: frame, editing: nil)
        return BoxGestureMath.result(gesture, layers: layers, document: document, sceneID: sceneID, frame: frame,
                                     box: box, list: list)
    }

    /// One undo step; a locked or missing layer throws and the group rolls back, so nothing changes.
    public func commitBox(_ gesture: BoxGesture, layers: [String], sceneID: String, frame: Int, box: Rect,
                          autoKey: Bool, in engine: inout CommandEngine) throws {
        let label = switch gesture { case .move: "Move"; case .scale: "Scale"; case .rotate: "Rotate" }
        let document = engine.document
        let changes = boxResult(gesture, layers: layers, document: document, sceneID: sceneID, frame: frame, box: box)
        let owner = LayerOwner.scene(sceneID)
        let properties = LiveProperties()
        try engine.group(label) { engine in
            for layer in document.layers(of: owner) ?? [] {
                for (property, value) in changes[layer.id]?.sorted(by: { $0.key < $1.key }) ?? [] {
                    // One layer per write, so each takes its own value; inside the group it is one step.
                    try properties.setValue(value, of: property, owner: owner, layerIDs: [layer.id], frame: frame,
                                            autoKey: autoKey, coalesceKey: nil, in: &engine)
                }
            }
        }
    }
}
