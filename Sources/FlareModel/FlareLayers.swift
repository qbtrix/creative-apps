// FlareLayers.swift: the edited owner's layers, top first (the symbol being edited in place, else the selected scene),
// and the edits the Layers section runs on them, each one FlareCore command through FlareWorkspace.apply.
// FlareCore keeps layers bottom first, so panel rows are reversed against it.
import FlareCore

/// Why a layer change was refused, for the view to show.
public enum FlareLayerError: Error, Equatable, Sendable {
    /// No document is open, or no scene is selected.
    case noDocument
    /// A layer name must have a character other than whitespace.
    case emptyName
    /// The engine refused the command.
    case command(CommandError)
    /// The workspace refused the change before running it, saying why.
    case refused(String)

    public var message: String {
        switch self {
        case .noDocument: "Open an animation and select a scene first."
        case .emptyName: "Type a name for the layer."
        case .refused(let reason): reason
        case .command(.invalidFPS): "Frame rate must be at least 1 fps."
        case .command(.invalidDuration): "Length can't be negative."
        case .command(.invalidGuidePosition): "A guide needs a position on the canvas."
        case .command(let error): "The layer could not be changed (\(error))."
        }
    }
}

/// A layer flag the Layers section toggles; the raw value is its toggle id.
public enum FlareLayerFlag: String, CaseIterable, Sendable {
    case visible, locked
}

/// How a layer edit changes the layer selection when it succeeds.
enum FlareLayerSelection {
    case keep
    case layer(String?)
}

extension FlareWorkspace {
    /// The layers of `propertyOwner`, bottom first: the symbol's while one is edited in place, else the selected
    /// scene's; nil with neither.
    var ownerLayers: [Layer]? { propertyOwner.flatMap { document?.layers(of: $0) } }

    /// The edited owner's layers, top first.
    public var layers: [Layer] { ownerLayers?.reversed() ?? [] }

    /// Adds "Layer N" with the smallest N no layer in the document uses as a
    /// name or id, above the selected layer (on top without one), and selects it.
    public mutating func addLayer() {
        guard let owner = propertyOwner, let ownerLayers else { return refuse(.noDocument) }
        let all = scenes.flatMap(\.layers) + (document?.symbols.flatMap(\.layers) ?? [])
        let taken = Set(all.flatMap { [$0.id, $0.name] })
        var n = 1
        while taken.contains("layer-\(n)") || taken.contains("Layer \(n)") { n += 1 }
        let layer = Layer(id: "layer-\(n)", name: "Layer \(n)")
        let below = ownerLayers.firstIndex { $0.id == selectedLayerID }
        apply(AddLayer(owner: owner, layer: layer, index: below.map { $0 + 1 }), selection: .layer(layer.id))
    }

    /// Removes a layer. Removing the selected layer selects the one below it in
    /// the panel, or the one above when it was the bottom layer.
    public mutating func removeLayer(_ id: String) {
        guard let owner = propertyOwner, let ownerLayers else { return refuse(.noDocument) }
        var selection = FlareLayerSelection.keep
        if id == selectedLayerID, let i = ownerLayers.firstIndex(where: { $0.id == id }) {
            let rest = ownerLayers.filter { $0.id != id }
            let neighbor = i > 0 ? i - 1 : 0
            selection = .layer(rest.indices.contains(neighbor) ? rest[neighbor].id : nil)
        }
        apply(RemoveLayer(owner: owner, layerID: id), selection: selection)
    }

    /// Renames a layer. Surrounding whitespace is dropped; a name with nothing
    /// else is refused and the old name stays.
    public mutating func renameLayer(_ id: String, to name: String) {
        guard let owner = propertyOwner, ownerLayers != nil else { return refuse(.noDocument) }
        let trimmed = String(name.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard !trimmed.isEmpty else { return refuse(.emptyName) }
        apply(RenameLayer(owner: owner, layerID: id, name: trimmed))
    }

    /// Flips one flag of one layer.
    public mutating func toggleLayerFlag(_ id: String, _ flag: FlareLayerFlag) {
        guard let owner = propertyOwner, let ownerLayers else { return refuse(.noDocument) }
        let layer = ownerLayers.first { $0.id == id }
        let visible = flag == .visible ? layer.map { !$0.isVisible } : nil
        let locked = flag == .locked ? layer.map { !$0.isLocked } : nil
        apply(SetLayerFlags(owner: owner, layerID: id, isVisible: visible, isLocked: locked))
    }

    /// Moves the layer at panel row `source` so it sits before row
    /// `destination` (a list drag's offsets, rows counted top first, so
    /// `destination` may equal the row count to mean the bottom).
    public mutating func moveLayer(from source: Int, to destination: Int) {
        guard let owner = propertyOwner, let ownerLayers else { return refuse(.noDocument) }
        let rows = Array(ownerLayers.reversed())
        guard rows.indices.contains(source), (0...rows.count).contains(destination) else {
            return refuse(.command(.invalidIndex(rows.indices.contains(source) ? destination : source)))
        }
        let row = destination > source ? destination - 1 : destination
        guard row != source else { return }
        apply(ReorderLayer(owner: owner, layerID: rows[source].id, toIndex: rows.count - 1 - row))
    }
}
