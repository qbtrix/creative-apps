// PhotoWorkspace.swift: the state behind Photo's window (raster editing).
// Holds the open canvas as a CoreRaster PixelBuffer, its layer stack (top
// first), the selected layer and the active tool. Linux-safe: no UI imports.
// PhotoApp changes it only through the methods here. Invariants: with a canvas
// open there is at least one layer, and the selection names one of them.
import CoreRaster

/// The tools on Photo's tool palette.
public enum PhotoTool: String, CaseIterable, Sendable {
    case move, marquee, brush, eraser, crop
}

public struct PhotoWorkspace: Sendable, Equatable {
    public private(set) var canvas: PixelBuffer?
    /// The layer stack, top first.
    public private(set) var layers: [PhotoLayer] = []
    public private(set) var selectedLayerID: PhotoLayer.ID?
    public private(set) var tool: PhotoTool = .move
    /// The number in the next layer's id; ids are never reused.
    private var nextLayerNumber = 1

    public init() {}

    public var selectedLayer: PhotoLayer? {
        layers.first { $0.id == selectedLayerID }
    }

    /// Whether Delete Layer can run: the last layer can't be removed.
    public var canRemoveLayer: Bool { layers.count > 1 }

    /// Opens a new white canvas with one "Background" layer. Throws
    /// `RasterError` for a size CoreRaster rejects; the workspace is unchanged.
    public mutating func newCanvas(width: Int, height: Int) throws {
        canvas = try PixelBuffer(width: width, height: height, fill: RGBA(r: 1, g: 1, b: 1, a: 1))
        layers = []
        nextLayerNumber = 1
        selectedLayerID = insertLayer(named: "Background", at: 0)
    }

    /// Selects a layer by id. An unknown id is ignored.
    public mutating func selectLayer(_ id: PhotoLayer.ID) {
        if index(of: id) != nil { selectedLayerID = id }
    }

    public mutating func selectTool(_ tool: PhotoTool) {
        self.tool = tool
    }

    /// Adds a visible, opaque, normal-blend layer named "Layer N" (the lowest
    /// N no layer uses) above the selected layer, and selects it. Ignored
    /// with no canvas open.
    public mutating func addLayer() {
        guard canvas != nil else { return }
        var number = 1
        while layers.contains(where: { $0.name == "Layer \(number)" }) { number += 1 }
        let above = selectedLayerID.flatMap(index(of:)) ?? 0
        selectedLayerID = insertLayer(named: "Layer \(number)", at: above)
    }

    /// Removes a layer and selects the one that took its place. Returns false,
    /// changing nothing, for the last layer or an unknown id.
    @discardableResult
    public mutating func removeLayer(_ id: PhotoLayer.ID) -> Bool {
        guard canRemoveLayer, let at = index(of: id) else { return false }
        layers.remove(at: at)
        if selectedLayerID == id { selectedLayerID = layers[min(at, layers.count - 1)].id }
        return true
    }

    /// Renames a layer. Surrounding spaces are dropped; an empty name is ignored.
    public mutating func renameLayer(_ id: PhotoLayer.ID, to name: String) {
        let trimmed = String(name.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard !trimmed.isEmpty, let at = index(of: id) else { return }
        layers[at].name = trimmed
    }

    /// Shows a hidden layer or hides a shown one.
    public mutating func toggleVisibility(_ id: PhotoLayer.ID) {
        guard let at = index(of: id) else { return }
        layers[at].isVisible.toggle()
    }

    /// Sets opacity from a percentage, clamped to 0...100. NaN is ignored.
    public mutating func setOpacity(_ id: PhotoLayer.ID, percent: Double) {
        guard !percent.isNaN, let at = index(of: id) else { return }
        layers[at].opacity = min(max(percent, 0), 100) / 100
    }

    public mutating func setBlendMode(_ id: PhotoLayer.ID, _ mode: BlendMode) {
        guard let at = index(of: id) else { return }
        layers[at].blendMode = mode
    }

    /// Moves the layers at `offsets` (top-first positions) to sit before the
    /// layer now at `destination`, as a list drag reports it; `layers.count`
    /// moves them to the bottom. Out-of-range offsets are ignored.
    public mutating func moveLayers(fromOffsets offsets: [Int], toOffset destination: Int) {
        let sources = Set(offsets.filter { layers.indices.contains($0) })
        guard !sources.isEmpty, (0...layers.count).contains(destination) else { return }
        let moving = layers.indices.filter { sources.contains($0) }.map { layers[$0] }
        var staying = layers.indices.filter { !sources.contains($0) }.map { layers[$0] }
        staying.insert(contentsOf: moving, at: destination - sources.filter { $0 < destination }.count)
        layers = staying
    }

    private func index(of id: PhotoLayer.ID) -> Int? {
        layers.firstIndex { $0.id == id }
    }

    /// Inserts a new default layer at `position` and returns its id.
    private mutating func insertLayer(named name: String, at position: Int) -> PhotoLayer.ID {
        let layer = PhotoLayer(id: "layer-\(nextLayerNumber)", name: name)
        nextLayerNumber += 1
        layers.insert(layer, at: min(max(position, 0), layers.count))
        return layer.id
    }
}
