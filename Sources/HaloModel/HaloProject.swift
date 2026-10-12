// HaloProject.swift: the state behind Halo's window (motion graphics). Holds
// the project's compositions, the selected one and the selected layer in it.
// Linux-safe: no UI imports. HaloApp changes it only through the methods here.
// The selected layer, when set, is always a layer of the selected composition.

/// A composition: a sized, timed canvas that layers play in.
public struct HaloComposition: Identifiable, Sendable, Hashable {
    public let id: String
    public var name: String
    public var width: Int
    public var height: Int
    public var framesPerSecond: Int
    public var durationFrames: Int
    /// The composition's layers, top first.
    public var layers: [HaloLayer]

    public init(
        id: String, name: String, width: Int, height: Int, framesPerSecond: Int, durationFrames: Int,
        layers: [HaloLayer] = []
    ) {
        self.id = id
        self.name = name
        self.width = width
        self.height = height
        self.framesPerSecond = framesPerSecond
        self.durationFrames = durationFrames
        self.layers = layers
    }

    /// Length in seconds; 0 when the frame rate is not positive.
    public var durationSeconds: Double {
        framesPerSecond > 0 ? Double(durationFrames) / Double(framesPerSecond) : 0
    }

    /// The layer count as the viewer's readout shows it ("3 layers").
    public var layerSummary: String {
        switch layers.count {
        case 0: "No layers"
        case 1: "1 layer"
        default: "\(layers.count) layers"
        }
    }
}

public struct HaloProject: Sendable, Equatable {
    public private(set) var compositions: [HaloComposition] = []
    public private(set) var selectedCompositionID: String?
    public private(set) var selectedLayerID: String?

    public init() {}

    public var selectedComposition: HaloComposition? {
        compositions.first { $0.id == selectedCompositionID }
    }

    public var selectedLayer: HaloLayer? {
        selectedComposition?.layers.first { $0.id == selectedLayerID }
    }

    /// Whether Layer > New can add a layer: only with a composition selected.
    public var canAddLayer: Bool { selectedComposition != nil }

    /// Adds a 1080p, 30 fps, 10 second composition named after its position
    /// and selects it.
    public mutating func newComposition() {
        let n = compositions.count + 1
        compositions.append(HaloComposition(
            id: "comp-\(n)", name: "Comp \(n)", width: 1920, height: 1080,
            framesPerSecond: 30, durationFrames: 300))
        selectedCompositionID = "comp-\(n)"
        selectedLayerID = nil
    }

    /// Selects a composition by id. An unknown id is ignored; selecting
    /// another composition clears the layer selection.
    public mutating func selectComposition(_ id: String) {
        guard compositions.contains(where: { $0.id == id }), id != selectedCompositionID else { return }
        selectedCompositionID = id
        selectedLayerID = nil
    }

    /// Adds a layer of `kind` on top of the selected composition, spanning its
    /// whole duration and named by kind ("Solid 1", "Solid 2"), and selects
    /// it. Does nothing with no composition selected.
    public mutating func newLayer(_ kind: HaloLayerKind) {
        guard let index = compositions.firstIndex(where: { $0.id == selectedCompositionID }) else { return }
        let comp = compositions[index]
        let number = comp.layers.filter { $0.kind == kind }.count + 1
        let layer = HaloLayer(
            id: "\(comp.id)-layer-\(comp.layers.count + 1)", name: "\(kind.title) \(number)", kind: kind,
            inFrame: 0, outFrame: comp.durationFrames, color: kind.defaultColor)
        compositions[index].layers.insert(layer, at: 0)
        selectedLayerID = layer.id
    }

    /// Selects a layer of the selected composition by id. An unknown id is
    /// ignored.
    public mutating func selectLayer(_ id: String) {
        if selectedComposition?.layers.contains(where: { $0.id == id }) == true { selectedLayerID = id }
    }
}
