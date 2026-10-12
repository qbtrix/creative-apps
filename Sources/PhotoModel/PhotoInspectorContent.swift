// PhotoInspectorContent.swift: what Photo's inspector shows for the current
// workspace: a "No Image" empty state with no canvas open, a "No Selection"
// empty state with a canvas but no selected layer, or the selected layer.
// Linux-safe: no UI imports.

public enum PhotoInspectorContent: Sendable, Hashable {
    case noImage
    case noSelection
    /// The selected layer and the open canvas's size in pixels.
    case layer(PhotoLayer, width: Int, height: Int)
}

extension PhotoWorkspace {
    public var inspectorContent: PhotoInspectorContent {
        guard let canvas else { return .noImage }
        guard let layer = selectedLayer else { return .noSelection }
        return .layer(layer, width: canvas.width, height: canvas.height)
    }
}
