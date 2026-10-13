// FlareGuides.swift: the selected scene's ruler guides (docs/blueprints/flare.md, 3.4 and J14): add, move, remove and
// Clear Guides. A guide drag is one coalesced "Move Guide" step, however many moves it sends.
import FlareCore

extension FlareWorkspace {
    /// The selected scene's guides, in the order they were added.
    public var guides: [Guide] { selectedScene?.guides ?? [] }

    /// Why Clear Guides is off, as its tooltip; nil when there are guides to clear.
    public var clearGuidesHelp: String? {
        guard selectedScene != nil else { return FlareLayerError.noDocument.message }
        return guides.isEmpty ? "There are no guides to clear." : nil
    }

    /// Adds a guide at `position` scene points, one "Add Guide" step.
    public mutating func addGuide(_ axis: Guide.Axis, at position: Double) {
        guard let sceneID = selectedSceneID else { return refuse(.noDocument) }
        let scenes = services.scenes
        step { _ = try scenes.addGuide(axis, at: position, sceneID: sceneID, in: &$0) }
    }

    /// Moves guide `index` to `position` during a drag that began with the guide at `start`. Moves of one drag share
    /// one "Move Guide" step; the next drag begins where this one ended, so it gets a step of its own.
    public mutating func moveGuide(at index: Int, to position: Double, dragStart start: Double) {
        guard let sceneID = selectedSceneID else { return refuse(.noDocument) }
        let scenes = services.scenes, key = "guide-\(sceneID)-\(index)-\(start)"
        step { try scenes.moveGuide(at: index, to: position, sceneID: sceneID, coalesceKey: key, in: &$0) }
    }

    /// Removes guide `index`, one "Remove Guide" step.
    public mutating func removeGuide(at index: Int) {
        guard let sceneID = selectedSceneID else { return refuse(.noDocument) }
        let scenes = services.scenes
        step { try scenes.removeGuide(at: index, sceneID: sceneID, in: &$0) }
    }

    /// Removes every guide of the selected scene in one "Clear Guides" step.
    public mutating func clearGuides() {
        guard clearGuidesHelp == nil, let sceneID = selectedSceneID else { return refuse(.refused(clearGuidesHelp ?? "")) }
        let scenes = services.scenes, count = guides.count
        step("Clear Guides") { engine in
            for index in (0..<count).reversed() { try scenes.removeGuide(at: index, sceneID: sceneID, in: &engine) }
        }
    }
}
