// PhotoHistory.swift: Photo's undo and redo. Every document edit records one
// step: a name ("Paint", "Crop") and the change that puts the document back
// (PhotoEdit). Undoing applies that change and keeps its inverse for Redo,
// and the reverse. Pixel edits keep only the changed tiles (CoreRaster's
// TileDiff); layer property and order changes keep the layer list, which
// holds no pixels; edits that add, remove or resize layers keep the whole
// stack. A run of edits with the same coalescing key (one slider's drag, one
// layer's opacity) is one step. A new edit clears Redo; the history keeps the
// last `limit` steps. Linux-safe.
import CoreRaster

/// The state an edit puts back.
enum PhotoEdit: Sendable, Equatable {
    /// One layer's changed tiles, applied backward (undo) or forward (redo).
    case pixels(layer: PhotoLayer.ID, diff: TileDiff, forward: Bool)
    /// The layer list (names, visibility, opacity, blend, offsets, order) and
    /// the selected layer; the same layers, so no pixels.
    case layers([PhotoLayer], selected: PhotoLayer.ID?)
    /// Everything about the image's layers and size.
    case stack(PhotoStack)
    case adjustments(AdjustmentSettings)
}

/// The whole layer stack, for edits that add, remove or resize layers.
struct PhotoStack: Sendable, Equatable {
    var canvas: CanvasSize?
    var layers: [PhotoLayer]
    var pixels: [PhotoLayer.ID: PixelBuffer]
    var selectedLayerID: PhotoLayer.ID?
    var selection: PixelRect?
}

struct PhotoHistory: Sendable, Equatable {
    struct Step: Sendable, Equatable {
        var name: String
        var edit: PhotoEdit
        var coalescing: String?
    }

    static let limit = 50
    var undo: [Step] = []
    var redo: [Step] = []
}

extension PhotoWorkspace {
    public var canUndo: Bool { !history.undo.isEmpty }
    public var canRedo: Bool { !history.redo.isEmpty }
    /// "Undo Paint", or plain "Undo" with nothing to undo.
    public var undoActionName: String { history.undo.last.map { "Undo \($0.name)" } ?? "Undo" }
    /// "Redo Paint", or plain "Redo" with nothing to redo.
    public var redoActionName: String { history.redo.last.map { "Redo \($0.name)" } ?? "Redo" }

    /// Puts back the last edit. Ignored with nothing to undo or mid-drag.
    public mutating func undo() {
        guard stroke == nil, let step = history.undo.popLast() else { return }
        history.redo.append(Step(name: step.name, edit: apply(step.edit), coalescing: nil))
    }

    /// Makes the last undone edit again.
    public mutating func redo() {
        guard stroke == nil, let step = history.redo.popLast() else { return }
        history.undo.append(Step(name: step.name, edit: apply(step.edit), coalescing: nil))
    }

    private typealias Step = PhotoHistory.Step

    /// Records `edit`, the change that undoes what is about to happen. With a
    /// `coalescing` key equal to the last step's, the last step already puts
    /// back the state before this run, so nothing new is kept.
    mutating func record(_ edit: PhotoEdit, named name: String, coalescing: String? = nil) {
        history.redo.removeAll()
        if let coalescing, history.undo.last?.coalescing == coalescing { return }
        history.undo.append(Step(name: name, edit: edit, coalescing: coalescing))
        if history.undo.count > PhotoHistory.limit { history.undo.removeFirst(history.undo.count - PhotoHistory.limit) }
    }

    /// Records the layer list as it is, before a property or order change.
    mutating func recordLayers(named name: String, coalescing: String? = nil) {
        record(.layers(layers, selected: selectedLayerID), named: name, coalescing: coalescing)
    }

    var stackState: PhotoStack {
        PhotoStack(canvas: canvas, layers: layers, pixels: pixels, selectedLayerID: selectedLayerID, selection: selection)
    }

    /// Applies `edit` and returns the edit that reverses it.
    private mutating func apply(_ edit: PhotoEdit) -> PhotoEdit {
        switch edit {
        case .pixels(let id, let diff, let forward):
            guard var buffer = pixels[id], let at = index(of: id) else { return edit }
            // The diff was made from this layer's buffer, so the sizes match and it can't throw.
            try? forward ? diff.redo(&buffer) : diff.undo(&buffer)
            pixels[id] = buffer
            touch(bounds(of: layers[at]).map { .region($0) } ?? .all)
            return .pixels(layer: id, diff: diff, forward: !forward)
        case .layers(let list, let selected):
            let inverse = PhotoEdit.layers(layers, selected: selectedLayerID)
            // Only ever recorded over the same ids; a mismatch would orphan pixels.
            guard Set(list.map(\.id)) == Set(pixels.keys) else { return edit }
            layers = list
            selectedLayerID = selected
            touch(.all)
            return inverse
        case .stack(let stack):
            let inverse = PhotoEdit.stack(stackState)
            restore(stack)
            touch(.all)
            return inverse
        case .adjustments(let settings):
            let inverse = PhotoEdit.adjustments(adjustments)
            adjustments = settings
            touch(.all)
            return inverse
        }
    }

    mutating func restore(_ stack: PhotoStack) {
        canvas = stack.canvas
        layers = stack.layers
        pixels = stack.pixels
        selectedLayerID = stack.selectedLayerID
        selection = stack.selection
        pendingCrop = nil
    }
}
