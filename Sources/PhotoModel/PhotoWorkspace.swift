// PhotoWorkspace.swift: the state behind Photo's window (raster editing).
// Holds the open canvas as a CoreRaster PixelBuffer, its layer names, the
// selected layer and the active tool. Linux-safe: no UI imports. PhotoApp
// changes it only through the methods here. The layer stack (P2) replaces
// `layerNames` with real layers.
import CoreRaster

/// The tools on Photo's tool palette.
public enum PhotoTool: String, CaseIterable, Sendable {
    case move, marquee, brush, eraser, crop
}

public struct PhotoWorkspace: Sendable, Equatable {
    public private(set) var canvas: PixelBuffer?
    public private(set) var layerNames: [String] = []
    public private(set) var selectedLayer: String?
    public private(set) var tool: PhotoTool = .move

    public init() {}

    /// Opens a new white canvas with one "Background" layer. Throws
    /// `RasterError` for a size CoreRaster rejects; the workspace is unchanged.
    public mutating func newCanvas(width: Int, height: Int) throws {
        canvas = try PixelBuffer(width: width, height: height, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
        layerNames = ["Background"]
        selectedLayer = "Background"
    }

    /// Selects a layer by name. An unknown name is ignored.
    public mutating func selectLayer(_ name: String) {
        if layerNames.contains(name) { selectedLayer = name }
    }

    public mutating func selectTool(_ tool: PhotoTool) {
        self.tool = tool
    }
}
