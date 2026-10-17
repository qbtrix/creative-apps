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

extension PhotoInspectorContent {
    /// The "No Image" empty state's title and SF Symbol, shared by the canvas
    /// and the inspector so both panes name the same state the same way.
    public static let noImageTitle = "No Image Open"
    public static let noImageSymbol = "photo.on.rectangle"

    /// The "No Image" empty state's next step. It names only commands Photo
    /// has (Open and File > New Image), as the canvas beside it does.
    public static let noImageMessage = "Open a photo or make one with File > New Image to adjust it."
}

extension PhotoWorkspace {
    /// The inspector's image header title: the document's name, or
    /// "Untitled" for an image that hasn't been saved or opened from a file.
    public var inspectorHeaderTitle: String { documentName ?? "Untitled" }

    /// The image header's fact lines under the title: the canvas size, then
    /// the color space and the layer count. None with no canvas or no
    /// selected layer. A selected pixel layer whose bounds differ from the
    /// canvas (a paste) adds its size and origin, e.g.
    /// "Pasted Layer 200 × 100 px at 300, 250".
    public var inspectorHeaderDetails: [String] {
        guard let canvas, let layer = selectedLayer else { return [] }
        let details = Self.headerDetails(width: canvas.width, height: canvas.height, layerCount: layers.count)
        guard let rect = bounds(of: layer),
            rect != PixelRect(x: 0, y: 0, width: canvas.width, height: canvas.height)
        else { return details }
        return details + ["\(layer.name) \(Self.sizeText(width: rect.width, height: rect.height)) at \(rect.x), \(rect.y)"]
    }

    /// The header lines for a `width` × `height` image with `layerCount`
    /// layers. Plain interpolation, so any Int formats without a trap.
    public static func headerDetails(width: Int, height: Int, layerCount: Int) -> [String] {
        [sizeText(width: width, height: height), "sRGB · \(layerCount) \(layerCount == 1 ? "layer" : "layers")"]
    }

    /// The viewer status bar's size text: the canvas size, plus the marquee
    /// selection's size while there is one; "No image" with no canvas.
    public var viewerSizeText: String {
        guard let canvas else { return "No image" }
        let size = Self.sizeText(width: canvas.width, height: canvas.height)
        guard let selection else { return size }
        return "\(size)  ·  Selection \(selection.width) × \(selection.height)"
    }

    static func sizeText(width: Int, height: Int) -> String { "\(width) × \(height) px" }
}
