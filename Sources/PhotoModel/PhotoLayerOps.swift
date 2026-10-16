// PhotoLayerOps.swift: the Layer menu's Duplicate Layer, Merge Down and
// Flatten Image (PV-2), each one named undo step, each with its reason when it
// can't run. Duplicate copies the selected layer, its tiles (copy-on-write, so
// painting one leaves the other alone) and its mask as "<name> copy" above it,
// and selects the copy. Merge Down hands the selected layer and the one below
// to `services.merging`; the lower layer keeps its id, name, blend, opacity and
// mask and takes the merged pixels and place, and the upper layer goes. Flatten
// Image makes one "Background" layer of `services.merging.flatten` and resets
// the whole-image adjustments in the same step, since they are now in the
// pixels. The help texts are workspace code (they read the stack), so `.fake`
// gives them too; a merging service that isn't built adds its own. A refusal
// from the service goes to `statusMessage` and changes nothing else. Both can
// take seconds, so the window runs them in three parts: `beginMerge` sets
// `progress` ("Merging…") and disables both items, `merged` works the pixels
// out off the main actor, and `commitMerge` applies them as the one step
// unless the image changed meanwhile. A flatten that baked in adjustments or
// dropped hidden layers says so in `statusMessage`.
// Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// Why Duplicate Layer can't run, or nil.
    public var duplicateLayerHelp: String? {
        guard canvas != nil else { return "Open an image first." }
        return selectedLayer == nil ? "Select a layer first." : nil
    }

    /// Copies the selected layer, its pixels and its mask as "<name> copy"
    /// just above it, and selects the copy: one "Duplicate Layer" step.
    public mutating func duplicateSelectedLayer() {
        if let help = duplicateLayerHelp {
            statusMessage = help
            return
        }
        guard let source = selectedLayer, let at = index(of: source.id) else { return }
        record(.stack(stackState), named: "Duplicate Layer")
        let id = insertLayer(named: "\(source.name) copy", pixels: pixels[source.id], kind: source.kind, at: at)
        if let copy = index(of: id) {
            layers[copy].isVisible = source.isVisible
            layers[copy].opacity = source.opacity
            layers[copy].blendMode = source.blendMode
            layers[copy].offsetX = source.offsetX
            layers[copy].offsetY = source.offsetY
            layers[copy].hasMask = source.hasMask
            layers[copy].isMaskEnabled = source.isMaskEnabled
        }
        masks[id] = masks[source.id]
        selectedLayerID = id
        layerGeometryChanged(id, .duplicated(from: source.id))
        touch(.all)
    }

    /// Why Merge Down can't run, or nil: no image, nothing below the selected
    /// layer, an adjustment layer below, a merge already running, or a merging
    /// service that isn't built.
    public var mergeDownHelp: String? {
        guard canvas != nil else { return "Open an image first." }
        guard let at = selectedLayerID.flatMap(index(of:)), layers.indices.contains(at + 1) else {
            return "There's no layer below to merge into."
        }
        if case .adjustment = layers[at + 1].kind { return "Merge Down needs a pixel layer below." }
        return progress == nil ? services.merging.unavailableHelp : Self.mergeBusyHelp
    }

    /// Why Flatten Image can't run, or nil: no image, one pixel layer and
    /// default whole-image adjustments (nothing to flatten), a merge already
    /// running, or a merging service that isn't built.
    public var flattenHelp: String? {
        guard canvas != nil else { return "Open an image first." }
        if layers.count == 1, !layers.contains(where: { $0.kind != .pixels }), adjustments == AdjustmentSettings() {
            return "The image already has one layer."
        }
        return progress == nil ? services.merging.unavailableHelp : Self.mergeBusyHelp
    }

    /// Merges the selected layer into the one below at once: one "Merge
    /// Down" step. The lower layer keeps its id and name and takes the merged
    /// pixels; the selected layer is removed and the lower one selected.
    public mutating func mergeDown() {
        guard beginMerge(.mergeDown) else { return }
        commitMerge(merged(.mergeDown))
    }

    /// Every visible layer and the whole-image adjustments as one "Background"
    /// layer at once, the adjustments reset to their defaults: one "Flatten
    /// Image" step.
    public mutating func flattenImage() {
        guard beginMerge(.flatten) else { return }
        commitMerge(merged(.flatten))
    }

    /// Starts `job`: sets `progress` to "Merging…" and returns true, or puts
    /// its help in the status line and returns false. Then `merged` (off the
    /// main actor) and `commitMerge`.
    public mutating func beginMerge(_ job: LayerMergeJob) -> Bool {
        if let help = job == .mergeDown ? mergeDownHelp : flattenHelp {
            statusMessage = help
            return false
        }
        progress = "Merging…"
        return true
    }

    /// `job`'s pixels, worked out without changing anything, so it can run
    /// off the main actor.
    public func merged(_ job: LayerMergeJob) -> LayerMergeResult {
        let outcome: LayerMergeResult.Outcome
        do {
            switch job {
            case .mergeDown:
                guard let at = selectedLayerID.flatMap(index(of:)), layers.indices.contains(at + 1) else {
                    throw PhotoRefusal("There's no layer below to merge into.")
                }
                let upper = content(of: layers[at]), lower = content(of: layers[at + 1])
                outcome = .placed(try services.merging.mergeDown(upper, onto: lower))
            case .flatten:
                guard let canvas else { throw PhotoRefusal("Open an image first.") }
                let all = layers.map(content(of:))
                outcome = .flat(try services.merging.flatten(all, canvas: canvas, adjustments: adjustments))
            }
        } catch let refusal as PhotoRefusal {
            outcome = .refused(refusal.message)
        } catch {
            outcome = .refused(job == .mergeDown ? "Couldn't merge these layers." : "Couldn't flatten the image.")
        }
        return LayerMergeResult(
            revision: revision, layers: layers, selectedLayerID: selectedLayerID, adjustments: adjustments,
            outcome: outcome)
    }

    /// Clears `progress` and makes `result` the image as one "Merge Down" or
    /// "Flatten Image" step, returning true. A refusal, or a result worked out
    /// before another change (or arriving mid-drag), goes to the status line
    /// and changes nothing else.
    @discardableResult
    public mutating func commitMerge(_ result: LayerMergeResult) -> Bool {
        progress = nil
        guard stroke == nil, result.revision == revision, result.layers == layers,
            result.selectedLayerID == selectedLayerID, result.adjustments == adjustments
        else {
            statusMessage = "The image changed while merging, so nothing was merged."
            return false
        }
        switch result.outcome {
        case .refused(let message):
            statusMessage = message
            return false
        case .placed(let placed): applyMergeDown(placed)
        case .flat(let flat): applyFlatten(flat)
        }
        touch(.all)
        return true
    }

    /// Merge Down's and Flatten Image's help while one of them runs.
    static let mergeBusyHelp = "Wait for the merge to finish."

    private mutating func applyMergeDown(_ placed: PlacedPixels) {
        guard let at = selectedLayerID.flatMap(index(of:)), layers.indices.contains(at + 1) else { return }
        let upper = layers[at], lower = layers[at + 1]
        record(.stack(stackState), named: "Merge Down")
        pixels[lower.id] = placed.pixels
        layers[at + 1].offsetX = placed.x
        layers[at + 1].offsetY = placed.y
        layers.remove(at: at)
        pixels[upper.id] = nil
        masks[upper.id] = nil
        selectedLayerID = lower.id
        // The lower layer's new bounds, in canvas pixels.
        layerGeometryChanged(
            lower.id,
            .cropped(PixelRect(x: placed.x, y: placed.y, width: placed.pixels.width, height: placed.pixels.height)))
        layerGeometryChanged(upper.id, .removed)
    }

    /// Flattens, and says in the status line what went into the pixels or was
    /// dropped, since sliders back at 0 and a missing layer don't say it.
    private mutating func applyFlatten(_ flat: TiledPixels) {
        let gone = layers.map(\.id)
        var notes: [String] = []
        if adjustments != AdjustmentSettings() { notes.append("Adjustments applied to the image.") }
        if layers.contains(where: { !$0.isVisible }) { notes.append("Hidden layers were discarded.") }
        record(.group([.stack(stackState), .adjustments(adjustments)]), named: "Flatten Image")
        layers = []
        pixels = [:]
        masks = [:]
        adjustments = AdjustmentSettings()
        selectedLayerID = insertLayer(named: "Background", pixels: flat, kind: .pixels, at: 0)
        for id in gone { layerGeometryChanged(id, .removed) }
        statusMessage = notes.isEmpty ? nil : notes.joined(separator: " ")
    }

    /// `layer` as the merging service reads it: its pixels and, when enabled,
    /// its mask, as the renderer composites it.
    private func content(of layer: PhotoLayer) -> LayerContent {
        LayerContent(layer: layer, pixels: pixels[layer.id], mask: layer.isMaskEnabled ? masks[layer.id] : nil)
    }
}

/// The Layer menu items that merge pixels, which can run off the main actor.
public enum LayerMergeJob: Sendable, Hashable {
    case mergeDown, flatten
}

/// A merge worked out by `PhotoWorkspace.merged`, waiting for `commitMerge`.
public struct LayerMergeResult: Sendable {
    /// What it was worked out from; `commitMerge` drops it if any of it moved.
    let revision: Int
    let layers: [PhotoLayer]
    let selectedLayerID: PhotoLayer.ID?
    let adjustments: AdjustmentSettings
    let outcome: Outcome

    enum Outcome: Sendable {
        case placed(PlacedPixels), flat(TiledPixels), refused(String)
    }
}
