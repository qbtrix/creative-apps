// FlareScenes.swift: the Layers tab's SCENES rows and the Scene inspector (docs/blueprints/flare.md, section 3), each
// edit one undo step through `services.scenes`. Removing the last scene is refused with the Remove button's reason.
import FlareCore

extension FlareWorkspace {
    /// Why scene `id` can't be removed, as the Remove button's tooltip; nil when it can.
    public func sceneRemoveHelp(_ id: String) -> String? {
        guard scenes.contains(where: { $0.id == id }) else { return FlareLayerError.noDocument.message }
        return scenes.count > 1 ? nil : FakeScenes.lastSceneMessage
    }

    /// Adds a scene the size, rate and length of the selected one (the web preset without one) and selects it.
    public mutating func addScene() {
        let preset = selectedScene.map {
            CanvasPreset(name: $0.name, width: $0.width, height: $0.height, fps: $0.fps, durationFrames: $0.durationFrames)
        } ?? .web
        let scenes = services.scenes
        var added: String?
        step { added = try scenes.addScene(preset, in: &$0) }
        if let added, layerError == nil { selectScene(added) }
    }

    /// Renames a scene. Surrounding whitespace is dropped; a name with nothing else is refused, and the scene's
    /// current name adds no undo step but, like any accepted rename, clears an earlier refusal (#629).
    public mutating func renameScene(_ id: String, to name: String) {
        let trimmed = String(name.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard !trimmed.isEmpty else { return refuse(.refused("Type a name for the scene.")) }
        guard self.scenes.first(where: { $0.id == id })?.name != trimmed else { layerError = nil; return }
        let scenes = services.scenes
        step { try scenes.renameScene(id, to: trimmed, in: &$0) }
    }

    /// Removes a scene, refused for the last one. Removing the selected scene selects the one after it, or the one
    /// before when it was last.
    public mutating func removeScene(_ id: String) {
        if let reason = sceneRemoveHelp(id) { return refuse(.refused(reason)) }
        let order = self.scenes.map(\.id), scenes = services.scenes
        step { try scenes.removeScene(id, in: &$0) }
        guard layerError == nil, id == selectedSceneID, let i = order.firstIndex(of: id) else { return }
        let rest = order.filter { $0 != id }
        if let next = rest.indices.contains(i) ? rest[i] : rest.last { selectScene(next) }
    }

    /// Moves the scene at row `source` so it sits before row `destination` (a list drag's offsets, so
    /// `destination` may equal the row count to mean the end).
    public mutating func moveScene(from source: Int, to destination: Int) {
        let rows = self.scenes
        guard rows.indices.contains(source), (0...rows.count).contains(destination) else { return refuse(.command(.invalidIndex(destination))) }
        let row = destination > source ? destination - 1 : destination
        guard row != source else { return }
        let scenes = services.scenes, id = rows[source].id
        step { try scenes.reorderScene(id, to: row, in: &$0) }
    }

    /// Sets the selected scene's size and background, or its frame rate and length, in one step. A value the engine
    /// would refuse is refused first with a sentence about the field (#571).
    public mutating func setSceneCanvas(width: Double, height: Double, background: FlareColor) {
        guard let id = selectedSceneID else { return refuse(.noDocument) }
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return refuse(.refused("Canvas size must be greater than 0."))
        }
        guard background.isFinite else { return refuse(.refused("Pick a valid background color.")) }
        let scenes = services.scenes
        step { try scenes.setCanvas(id, width: width, height: height, background: background, in: &$0) }
    }
    public mutating func setSceneTiming(fps: Int, durationFrames: Int) {
        guard let id = selectedSceneID else { return refuse(.noDocument) }
        guard fps > 0 else { return refuse(.command(.invalidFPS(fps))) }
        guard durationFrames >= 0 else { return refuse(.command(.invalidDuration(durationFrames))) }
        if let label = selectedScene?.labels.filter({ $0.value > durationFrames }).min(by: { $0.key < $1.key }) {
            return refuse(.refused("Length must reach frame \(label.value), where the label \u{201C}\(label.key)\u{201D} sits."))
        }
        let scenes = services.scenes
        step { try scenes.setTiming(id, fps: fps, durationFrames: durationFrames, in: &$0) }
    }
}
