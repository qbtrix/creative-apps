// FlareInspectorRead.swift: what the inspector's header and info card show (inspector-timeline IT-1). Read-only.
// Nothing selected reads the scene; one layer reads its name, kind, size at the playhead and the keys on its timeline
// row; several read "<n> layers" with no key count. Inside an edited symbol the layers are the symbol's.
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
    /// The inspector header and info card: the scene when no layer is selected, else the inspector's layers
    /// (`propertyLayerIDs`) at the playhead. Several layers of different kinds read "Mixed".
    public var inspectorSummary: InspectorSummary {
        let layers = propertyLayerIDs.compactMap { id in ownerLayers?.first { $0.id == id } }
        guard let first = layers.first else {
            return InspectorSummary(title: selectedScene?.name ?? "", kind: "Scene", frame: currentFrame,
                                    size: sceneSizeText ?? "", keys: nil, showsScene: true)
        }
        let kind = Set(layers.map(Self.inspectorKind)).count == 1 ? Self.inspectorKind(first) : "Mixed"
        let size = inspectorBounds(of: layers.map(\.id)).map {
            "\(Self.whole($0.maxX - $0.minX)) × \(Self.whole($0.maxY - $0.minY)) px"
        } ?? "–"
        guard layers.count == 1 else {
            return InspectorSummary(title: "\(layers.count) layers", kind: kind, frame: currentFrame, size: size,
                                    keys: nil, showsScene: false)
        }
        let keys = timelineRows.first { $0.layerID == first.id }?.keyFrames.count ?? 0
        return InspectorSummary(title: first.name, kind: kind, frame: currentFrame, size: size, keys: keys,
                                showsScene: false)
    }

    /// "Instance" for a layer holding only symbol placements, "Group" for one mixing placements with drawn content,
    /// else "Shape".
    static func inspectorKind(_ layer: Layer) -> String {
        guard !layer.instances.isEmpty else { return "Shape" }
        return layer.shapes.isEmpty && layer.texts.isEmpty ? "Instance" : "Group"
    }

    /// The stage selection's box when there is one, else the box of every item on `layerIDs` at the playhead.
    func inspectorBounds(of layerIDs: [String]) -> Rect? {
        if !selection.isEmpty { return selectionBounds }
        guard let sceneID = selectedSceneID, let document else { return nil }
        let items = services.stage.drawList(document, sceneID: sceneID, frame: currentFrame, editing: editingSymbolID)
            .items.map(\.address).filter { layerIDs.contains($0.layerID) }
        guard !items.isEmpty else { return nil }
        return services.hits.bounds(document, sceneID: sceneID, frame: currentFrame, editing: editingSymbolID, of: items)
    }
}
