// PhotoHistory.swift: Photo's undo and redo, a thin adapter over SuiteKernel's
// History, where the stack, the step ids and the open run live; the adapter
// adds the base step's name. Every document edit records one
// step: a name ("Paint", "Crop") and the change that puts the document back
// (PhotoEdit). Undoing applies that change and keeps its inverse for Redo,
// and the reverse. Pixel edits keep only the tiles they changed, as they were
// (undo swaps them back); layer property and order changes keep the layer list, which
// holds no pixels; edits that add, remove or resize layers keep the whole
// stack. A run of edits with the same coalescing key (one slider's drag, one
// layer's opacity) is one step, until endAdjust closes it at the gesture's end (an undo
// or redo closes it too). A new edit clears Redo; the history keeps the
// last `limit` steps. The history list reads both stacks as one row of named
// steps, from how the image began ("New Image", "Open") to the last redo, and
// jumping to a step undoes or redoes up to it. Every step has an id from a
// counter that never repeats; `currentStepID` names the state the image is at
// and `isDirty` compares it with the step last saved, opened or created.
// Linux-safe.
import CoreRaster
import SuiteKernel

/// The state an edit puts back.
enum PhotoEdit: Sendable, Equatable {
    /// One layer's changed tiles as they were, by tile index (TiledPixels).
    case tiles(layer: PhotoLayer.ID, [Int: PixelBuffer])
    /// The layer list (names, visibility, opacity, blend, offsets, order) and
    /// the selected layer; the same layers, so no pixels.
    case layers([PhotoLayer], selected: PhotoLayer.ID?)
    /// Everything about the image's layers and size.
    case stack(PhotoStack)
    case adjustments(AdjustmentSettings)
    /// The selection rectangle and its coverage mask, as they were.
    case selection(PixelRect?, Mask?)
    /// One layer mask's changed tiles as they were, by tile index.
    case maskTiles(layer: PhotoLayer.ID, [Int: PixelBuffer])
    /// Several edits put back as one step (Flatten Image: the stack and the
    /// adjustments); applied in order, their inverses in reverse.
    case group([PhotoEdit])
}

/// The whole layer stack, for edits that add, remove or resize layers.
struct PhotoStack: Sendable, Equatable {
    var canvas: CanvasSize?
    var layers: [PhotoLayer]
    var pixels: [PhotoLayer.ID: TiledPixels]
    var masks: [PhotoLayer.ID: TiledPixels]
    var selectedLayerID: PhotoLayer.ID?
    var selection: PixelRect?
}

struct PhotoHistory: Sendable {
    static let limit = 50
    /// The first step: how the image began, or the newest step the limit
    /// dropped, since the oldest state left is the one after it. The kernel
    /// keeps no base, so the adapter does.
    var baseName = "New Image"
    /// The steps, their edits and ids, the open run and the limit.
    var kernel = History<PhotoEdit>(limit: PhotoHistory.limit)
    /// The open run's key, as the kernel keeps it: a record under it folds
    /// instead of adding a step, so it drops nothing at the limit.
    var runKey: String?
}

extension PhotoHistory: Equatable {
    /// Equal when they show the same steps at the same place and run (History
    /// isn't Equatable); the workspace's `revision` tells different edits apart.
    static func == (lhs: PhotoHistory, rhs: PhotoHistory) -> Bool {
        lhs.baseName == rhs.baseName && lhs.kernel.steps == rhs.kernel.steps
            && lhs.kernel.index == rhs.kernel.index && lhs.kernel.currentStepID == rhs.kernel.currentStepID
            && lhs.kernel.canUndo == rhs.kernel.canUndo && lhs.kernel.canRedo == rhs.kernel.canRedo
            && lhs.runKey == rhs.runKey
    }
}

extension PhotoWorkspace {
    public var canUndo: Bool { history.kernel.canUndo }
    public var canRedo: Bool { history.kernel.canRedo }
    /// "Undo Paint", or plain "Undo" with nothing to undo.
    public var undoActionName: String { history.kernel.undoName.map { "Undo \($0)" } ?? "Undo" }
    /// "Redo Paint", or plain "Redo" with nothing to redo.
    public var redoActionName: String { history.kernel.redoName.map { "Redo \($0)" } ?? "Redo" }

    /// The id of the step the image is at: the newest applied step's, or the
    /// base's with nothing to undo. Never the same for two different states.
    public var currentStepID: Int { history.kernel.currentStepID }

    /// Whether the open image has changes since it was last saved, opened or
    /// created. False with no image open.
    public var isDirty: Bool { canvas != nil && savedStepID != currentStepID }

    /// Puts back the last edit. Ignored with nothing to undo or mid-drag.
    public mutating func undo() {
        guard stroke == nil else { return }
        moveHistory { _ = $0.undo($1) }
    }

    /// Makes the last undone edit again.
    public mutating func redo() {
        guard stroke == nil else { return }
        moveHistory { _ = $0.redo($1) }
    }

    /// Every step's name, oldest first: how the image began, each edit that
    /// can be undone, then each that can be redone. Empty with no image.
    public var historySteps: [String] {
        guard canvas != nil else { return [] }
        return [history.baseName] + history.kernel.steps
    }

    /// The index in `historySteps` of the step the image is at now; later
    /// steps are the ones Redo makes again.
    public var historyIndex: Int { history.kernel.index }

    /// Undoes or redoes until the image is at `historySteps[index]`. Ignored
    /// out of range, mid-drag or at the current step.
    public mutating func jumpToHistoryStep(_ index: Int) {
        guard stroke == nil, historySteps.indices.contains(index), index != historyIndex else { return }
        moveHistory { $0.jump(to: index, $1) }
    }

    /// Ends the run the last undo step is coalescing (a slider's or a curve's
    /// drag), so the next edit, even to the same section, is a new step. The
    /// inspector calls it when a gesture ends: one gesture, one undo step.
    public mutating func endAdjust() {
        history.kernel.endRun()
        history.runKey = nil
    }

    /// Runs `move` (an undo, a redo or a jump) on the kernel with `apply` as
    /// its closure. The kernel is taken out while it runs, since `apply`
    /// changes the workspace; that also spares a copy of the steps. The
    /// kernel ends the open run on every move.
    private mutating func moveHistory(_ move: (inout History<PhotoEdit>, (PhotoEdit) -> PhotoEdit) -> Void) {
        var kernel = history.kernel
        history.kernel = History(limit: PhotoHistory.limit)
        move(&kernel) { apply($0) }
        history.kernel = kernel
        history.runKey = nil
    }

    /// Records `edit`, the change that undoes what is about to happen. With a
    /// `coalescing` key equal to the open run's, the last step already puts
    /// back the state before this run, so nothing new is kept; it takes a new
    /// id, since the state it leads to changes. A new step at the limit drops
    /// the oldest, whose name becomes the base.
    mutating func record(_ edit: PhotoEdit, named name: String, coalescing: String? = nil) {
        let folds = coalescing != nil && coalescing == history.runKey && history.kernel.canUndo
        if !folds, history.kernel.index >= PhotoHistory.limit, let oldest = history.kernel.steps.first {
            history.baseName = oldest
        }
        history.kernel.record(name, edit, key: coalescing)
        history.runKey = coalescing
    }

    /// Records the layer list as it is, before a property or order change.
    mutating func recordLayers(named name: String, coalescing: String? = nil) {
        record(.layers(layers, selected: selectedLayerID), named: name, coalescing: coalescing)
    }

    var stackState: PhotoStack {
        PhotoStack(
            canvas: canvas, layers: layers, pixels: pixels, masks: masks, selectedLayerID: selectedLayerID,
            selection: selection)
    }

    /// Applies `edit` and returns the edit that reverses it.
    private mutating func apply(_ edit: PhotoEdit) -> PhotoEdit {
        switch edit {
        case .tiles(let id, let saved):
            guard let inverse = swapTiles(saved, of: id, in: \.pixels) else { return edit }
            return .tiles(layer: id, inverse)
        case .maskTiles(let id, let saved):
            guard let inverse = swapTiles(saved, of: id, in: \.masks) else { return edit }
            return .maskTiles(layer: id, inverse)
        case .selection(let rect, let mask):
            let inverse = PhotoEdit.selection(selection, selectionMask)
            selection = rect
            selectionMask = mask
            return inverse
        case .layers(let list, let selected):
            let inverse = PhotoEdit.layers(layers, selected: selectedLayerID)
            // Only ever recorded over the same ids; a mismatch would orphan
            // pixels. Only pixel layers have pixels (an adjustment layer none).
            guard Set(list.filter { $0.kind == .pixels }.map(\.id)) == Set(pixels.keys) else { return edit }
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
            touch(.all, adjustmentsOnly: true)
            return inverse
        case .group(let edits):
            return .group(edits.map { apply($0) }.reversed())
        }
    }

    /// Puts `saved` tiles back into layer `id`'s buffer in `store` (its pixels
    /// or its mask) and returns the tiles they replaced; nil for an unknown layer.
    private mutating func swapTiles(
        _ saved: [Int: PixelBuffer], of id: PhotoLayer.ID,
        in store: WritableKeyPath<PhotoWorkspace, [PhotoLayer.ID: TiledPixels]>
    ) -> [Int: PixelBuffer]? {
        guard let at = index(of: id), var layer = self[keyPath: store].removeValue(forKey: id) else { return nil }
        var inverse: [Int: PixelBuffer] = [:], area = PixelRect(x: 0, y: 0, width: 0, height: 0)
        // Kept from this buffer at this size, so every index and size matches.
        for (i, tile) in saved where layer.tiles.indices.contains(i) {
            inverse[i] = layer.tiles[i]
            layer.tiles[i] = tile
            area = area.union(layer.tileRect(i))
        }
        self[keyPath: store][id] = layer
        touch(.region(area.offsetBy(layers[at].offsetX, layers[at].offsetY)))
        return inverse
    }

    mutating func restore(_ stack: PhotoStack) {
        canvas = stack.canvas
        layers = stack.layers
        pixels = stack.pixels
        masks = stack.masks
        selectedLayerID = stack.selectedLayerID
        selection = stack.selection
        pendingCrop = nil
    }
}
