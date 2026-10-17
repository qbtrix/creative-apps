// FlareInspectorRead.swift: what the inspector's header and info card show (inspector-timeline IT-1). Read-only.
// IT-0 declares the signature as a stub (lead.md rule 18) built from what the workspace already knows; IT-1 fills
// in the kind, size and key count without changing it.
import FlareCore

/// The inspector header and info card for the current selection, or for the scene when nothing is selected.
public struct InspectorSummary: Sendable, Equatable {
    /// The selection's name, "2 layers", or the scene's name.
    public var title: String
    /// The info card: "Shape", "Instance" or "Group", the playhead frame, the selection's size, and its key count
    /// (nil for several layers or the scene).
    public var kind: String, frame: Int, size: String, keys: Int?
    /// True when nothing is selected, so the inspector shows the scene.
    public var showsScene: Bool

    public init(title: String, kind: String, frame: Int, size: String, keys: Int?, showsScene: Bool) {
        (self.title, self.kind, self.frame, self.size, self.keys, self.showsScene) =
            (title, kind, frame, size, keys, showsScene)
    }
}

extension FlareWorkspace {
    /// Stub (IT-0): the selected layer's name, or the scene's name with `showsScene` when no layer is selected.
    public var inspectorSummary: InspectorSummary {
        guard let id = selectedLayerID, let layer = ownerLayers?.first(where: { $0.id == id }) else {
            return InspectorSummary(title: selectedScene?.name ?? "", kind: "Scene", frame: currentFrame,
                                    size: "", keys: nil, showsScene: true)
        }
        return InspectorSummary(title: layer.name, kind: "Shape", frame: currentFrame, size: "", keys: nil,
                                showsScene: false)
    }
}
