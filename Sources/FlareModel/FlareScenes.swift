// FlareScenes.swift: the Layers tab's SCENES rows and the Scene inspector (docs/blueprints/flare.md, section 3), each
// edit one undo step through `services.scenes`. Removing the last scene, or one a machine's state uses (the engine's
// rule, #683), is refused with the Remove button's reason; a refusal from the engine still gets plain words.
import FlareCore

extension FlareWorkspace {
    /// The selected scene's size in the stage's unit, "550 × 400 px", matching the ruler corner's "px" (#1846).
    public var sceneSizeText: String? {
        selectedScene.map { "\(Self.whole($0.width)) × \(Self.whole($0.height)) px" }
    }
    /// The selected scene's frame rate, "24 fps".
    public var sceneRateText: String? { selectedScene.map { "\($0.fps) fps" } }
    /// The selected scene's size and rate on one line, "550 × 400 px · 24 fps".
    public var sceneSummary: String? {
        guard let size = sceneSizeText, let rate = sceneRateText else { return nil }
        return "\(size) · \(rate)"
    }

    /// The Properties tab's empty state as (title, message): with no animation open it says to create or open one,
    /// since there is no scene to select (#1848); with one open, to select a scene.
    public var inspectorEmptyText: (title: String, message: String) {
        document == nil
            ? ("No Animation", "Create or open an animation to see its properties.")
            : ("No Selection", "Select a scene to see its properties.")
    }

    /// A whole-number readout that never traps on a non-finite or out-of-range value.
    static func whole(_ value: Double) -> String {
        guard value.isFinite, abs(value) < 1e15 else { return "–" }
        return String(Int(value.rounded()))
    }

    /// Why scene `id` can't be removed, as the Remove button's tooltip; nil when it can.
    public func sceneRemoveHelp(_ id: String) -> String? {
        guard scenes.contains(where: { $0.id == id }) else { return FlareLayerError.noDocument.message }
        guard scenes.count > 1 else { return FakeScenes.lastSceneMessage }
        guard let user = machines.first(where: { $0.states.contains { $0.sceneID == id } }) else { return nil }
        // The initial state can't be removed, so its reason names steps that work (#694).
        if let initial = user.states.first(where: { $0.id == user.initialState && $0.sceneID == id }) {
            return "The machine \u{201C}\(user.name)\u{201D} starts in \u{201C}\(initial.name)\u{201D} on this scene, and its "
                + "initial state can't be removed. Move that state to another scene or remove the machine first."
        }
        return "The machine \u{201C}\(user.name)\u{201D} uses this scene. Move its states on this scene to another scene "
            + "or remove them first."
    }

    /// The plain words for an engine refusal of Remove Scene, never its debug text (#683).
    static func sceneRemoveMessage(_ error: CommandError) -> String {
        if case .sceneNotFound = error { return "This scene is no longer in the document." }
        return "The scene could not be removed."
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

    /// Removes a scene, refused for the last one or one a machine uses. Removing the selected scene selects the one after it, or the one
    /// before when it was last.
    public mutating func removeScene(_ id: String) {
        if let reason = sceneRemoveHelp(id) { return refuse(.refused(reason)) }
        let order = self.scenes.map(\.id), scenes = services.scenes
        step { try scenes.removeScene(id, in: &$0) }
        if case .command(let error)? = layerError { return refuse(.refused(Self.sceneRemoveMessage(error))) }
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
        // Name the furthest label (ties by name), so typing the frame it names is accepted (#632).
        if let label = selectedScene?.labels.filter({ $0.value > durationFrames })
            .max(by: { ($0.value, $1.key) < ($1.value, $0.key) }) {
            return refuse(.refused("Length must reach frame \(label.value), where the label \u{201C}\(label.key)\u{201D} sits."))
        }
        let scenes = services.scenes
        step { try scenes.setTiming(id, fps: fps, durationFrames: durationFrames, in: &$0) }
    }
}
