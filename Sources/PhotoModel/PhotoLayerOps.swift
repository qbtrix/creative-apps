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
// from the service goes to `statusMessage` and changes nothing else.
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
    /// layer, an adjustment layer below, or a merging service that isn't built.
    public var mergeDownHelp: String? {
        guard canvas != nil else { return "Open an image first." }
        guard let at = selectedLayerID.flatMap(index(of:)), layers.indices.contains(at + 1) else {
            return "There's no layer below to merge into."
        }
        if case .adjustment = layers[at + 1].kind { return "Merge Down needs a pixel layer below." }
        return services.merging.unavailableHelp
    }

    /// Merges the selected layer into the one below: one "Merge Down" step.
    /// The lower layer keeps its id and name and takes the merged pixels; the
    /// selected layer is removed and the lower one selected.
    public mutating func mergeDown() {
        if let help = mergeDownHelp {
            statusMessage = help
            return
        }
        guard let at = selectedLayerID.flatMap(index(of:)), layers.indices.contains(at + 1) else { return }
        let upper = layers[at], lower = layers[at + 1]
        let placed: PlacedPixels
        do {
            placed = try services.merging.mergeDown(content(of: upper), onto: content(of: lower))
        } catch let refusal as PhotoRefusal {
            statusMessage = refusal.message
            return
        } catch {
            statusMessage = "Couldn't merge these layers."
            return
        }
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
        touch(.all)
    }

    /// Why Flatten Image can't run, or nil: no image, or one pixel layer and
    /// default whole-image adjustments (nothing to flatten), or a merging
    /// service that isn't built.
    public var flattenHelp: String? {
        guard canvas != nil else { return "Open an image first." }
        if layers.count == 1, !layers.contains(where: { $0.kind != .pixels }), adjustments == AdjustmentSettings() {
            return "The image already has one layer."
        }
        return services.merging.unavailableHelp
    }

    /// Every visible layer and the whole-image adjustments as one "Background"
    /// layer, the adjustments reset to their defaults: one "Flatten Image" step.
    public mutating func flattenImage() {
        if let help = flattenHelp {
            statusMessage = help
            return
        }
        guard let canvas else { return }
        let flat: TiledPixels
        do {
            flat = try services.merging.flatten(layers.map(content(of:)), canvas: canvas, adjustments: adjustments)
        } catch let refusal as PhotoRefusal {
            statusMessage = refusal.message
            return
        } catch {
            statusMessage = "Couldn't flatten the image."
            return
        }
        let gone = layers.map(\.id)
        record(.group([.stack(stackState), .adjustments(adjustments)]), named: "Flatten Image")
        layers = []
        pixels = [:]
        masks = [:]
        adjustments = AdjustmentSettings()
        selectedLayerID = insertLayer(named: "Background", pixels: flat, kind: .pixels, at: 0)
        for id in gone { layerGeometryChanged(id, .removed) }
        touch(.all)
    }

    /// `layer` as the merging service reads it: its pixels and, when enabled,
    /// its mask, as the renderer composites it.
    private func content(of layer: PhotoLayer) -> LayerContent {
        LayerContent(layer: layer, pixels: pixels[layer.id], mask: layer.isMaskEnabled ? masks[layer.id] : nil)
    }
}
