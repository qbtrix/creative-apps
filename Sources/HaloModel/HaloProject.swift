// HaloProject.swift: the state behind Halo's window (motion graphics). Holds
// the project's compositions, the selected one and the selected layer in it.
// Linux-safe: no UI imports. HaloApp changes it only through the methods here.
// The selected layer, when set, is always a layer of the selected composition.
// Composition ids are never reused and names stay unique; once a project has a
// composition it always keeps at least one. A refused rename of a known
// composition stays in `refusedRename` until a rename succeeds or it is
// dismissed.
import CoreRaster

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
    /// The last refused rename, so the window can show why; nil once handled.
    public private(set) var refusedRename: RefusedRename?
    /// The number in the next composition's id ("comp-3"); only goes up.
    private var nextCompositionNumber = 1

    public init() {}

    public var selectedComposition: HaloComposition? {
        compositions.first { $0.id == selectedCompositionID }
    }

    public var selectedLayer: HaloLayer? {
        selectedComposition?.layers.first { $0.id == selectedLayerID }
    }

    /// Whether Layer > New can add a layer: only with a composition selected.
    public var canAddLayer: Bool { selectedComposition != nil }

    /// What the New Composition sheet starts with: 1080p, 30 fps, 10 seconds,
    /// named after the next id ("Comp 3").
    public var suggestedSettings: CompositionSettings {
        CompositionSettings(name: uniqueName("Comp \(nextCompositionNumber)"))
    }

    /// Whether Delete can remove a composition: never the last one.
    public var canDeleteComposition: Bool { compositions.count > 1 }

    /// Adds a composition with the suggested settings and selects it.
    public mutating func newComposition() {
        newComposition(suggestedSettings)
    }

    /// Adds a composition from valid `settings` and selects it; a taken name gets a number.
    @discardableResult
    public mutating func newComposition(_ settings: CompositionSettings) -> Bool {
        guard let frames = settings.durationFrames else { return false }
        let comp = HaloComposition(
            id: takeCompositionID(), name: uniqueName(settings.name.trimmed), width: settings.width,
            height: settings.height, framesPerSecond: settings.framesPerSecond, durationFrames: frames)
        compositions.append(comp)
        selectedCompositionID = comp.id
        selectedLayerID = nil
        return true
    }

    /// Copies a composition and its layers in under the original, named
    /// "<name> copy" ("<name> copy 2", ...), and selects the copy. An unknown
    /// id is refused.
    @discardableResult
    public mutating func duplicateComposition(_ id: String) -> Bool {
        guard let index = compositions.firstIndex(where: { $0.id == id }) else { return false }
        let original = compositions[index]
        let newID = takeCompositionID()
        let layers = original.layers.map { layer in
            let suffix = layer.id.hasPrefix(original.id) ? String(layer.id.dropFirst(original.id.count)) : "-\(layer.id)"
            return layer.withID(newID + suffix)
        }
        let copy = HaloComposition(
            id: newID, name: uniqueName("\(original.name) copy"), width: original.width, height: original.height,
            framesPerSecond: original.framesPerSecond, durationFrames: original.durationFrames, layers: layers)
        compositions.insert(copy, at: index + 1)
        selectedCompositionID = newID
        selectedLayerID = nil
        return true
    }

    /// Renames a composition; an empty or taken name, or an unknown id, is
    /// refused. Refusing a known composition keeps the typed name and the
    /// reason in `refusedRename`; a rename that succeeds clears it.
    @discardableResult
    public mutating func renameComposition(_ id: String, to name: String) -> Bool {
        guard let index = compositions.firstIndex(where: { $0.id == id }) else { return false }
        if let problem = renameProblem(id, to: name) {
            refusedRename = RefusedRename(id: id, name: name, problem: problem)
            return false
        }
        compositions[index].name = name.trimmed
        refusedRename = nil
        return true
    }

    /// Why renaming composition `id` to `name` would be refused, as the alert
    /// says it; nil when the rename would succeed. Names that look the same
    /// (surrounding whitespace, letter case, composed or decomposed accents)
    /// count as taken.
    public func renameProblem(_ id: String, to name: String) -> String? {
        let name = name.trimmed
        guard compositions.contains(where: { $0.id == id }) else { return "The composition no longer exists." }
        if name.isEmpty { return "Enter a name for the composition." }
        let key = name.nameKey
        if compositions.contains(where: { $0.id != id && $0.name.nameKey == key }) {
            return "“\(name)” is already used by another composition. Choose a different name."
        }
        return nil
    }

    /// Forgets the refused rename, as when the user cancels it.
    public mutating func dismissRefusedRename() {
        refusedRename = nil
    }

    /// Deletes a composition, never the last one; deleting the selected one
    /// selects its neighbor below (or above, at the end).
    @discardableResult
    public mutating func deleteComposition(_ id: String) -> Bool {
        guard canDeleteComposition, let index = compositions.firstIndex(where: { $0.id == id }) else { return false }
        compositions.remove(at: index)
        if refusedRename?.id == id { refusedRename = nil }
        if selectedCompositionID == id {
            selectedCompositionID = compositions[min(index, compositions.count - 1)].id
            selectedLayerID = nil
        }
        return true
    }

    /// The next unused composition id.
    private mutating func takeCompositionID() -> String {
        defer { nextCompositionNumber += 1 }
        return "comp-\(nextCompositionNumber)"
    }

    /// `base`, or `base` with the first free number after it ("Comp 1 copy 2").
    /// Names compare as `renameProblem` compares them, so a look-alike is taken.
    private func uniqueName(_ base: String) -> String {
        let keys = Set(compositions.map(\.name.nameKey))
        guard keys.contains(base.nameKey) else { return base }
        var number = 2
        while keys.contains("\(base) \(number)".nameKey) { number += 1 }
        return "\(base) \(number)"
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

    /// Sets the selected layer's opacity, clamped to 0...1; NaN is ignored.
    public mutating func setSelectedLayerOpacity(_ opacity: Double) {
        guard !opacity.isNaN else { return }
        updateSelectedLayer { $0.opacity = min(max(opacity, 0), 1) }
    }

    /// Sets how the selected layer blends with the layers under it.
    public mutating func setSelectedLayerBlendMode(_ mode: BlendMode) {
        updateSelectedLayer { $0.blendMode = mode }
    }

    private mutating func updateSelectedLayer(_ change: (inout HaloLayer) -> Void) {
        guard let c = compositions.firstIndex(where: { $0.id == selectedCompositionID }),
            let l = compositions[c].layers.firstIndex(where: { $0.id == selectedLayerID })
        else { return }
        change(&compositions[c].layers[l])
    }
}
