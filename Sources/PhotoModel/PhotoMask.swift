// PhotoMask.swift: layer masks (PV-5, masks-clipping). The geometry hook: every
// change to a layer's size or place (crop, Image Size, Canvas Size, rotate,
// straighten, delete, and PV-2's and PV-7's own edits) calls
// `layerGeometryChanged`, so each mask keeps the size and place of its layer.
// Then the mask edits the Layer menu runs (add, delete, apply, enable, edit)
// with their reasons, each one undo step (PK-5). A mask is grey (r = g = b, the
// coverage 0...1) with alpha 1, the size of its layer's pixels. Linux-safe.
import CoreRaster

/// A geometry change every layer's extras (its mask) must follow.
public enum LayerGeometryChange: Hashable, Sendable {
    /// Cut to a canvas rect, sent before the pixels are cut (offsets still the old ones).
    case cropped(PixelRect)
    /// Canvas Size: every layer moved by (dx, dy); a padded background grew to the canvas.
    case canvasResized(dx: Int, dy: Int)
    case resized(scaleX: Double, scaleY: Double)
    case rotated(QuarterTurn)
    case straightened(degrees: Double, crop: PixelRect)
    case flippedCanvas(FlipAxis)
    case transformed(LayerTransform)
    case flipped(FlipAxis)
    case duplicated(from: PhotoLayer.ID)
    case removed
}

extension PhotoWorkspace {
    /// Layer `id`'s geometry changed by `change`; its mask moves along.
    mutating func layerGeometryChanged(_ id: PhotoLayer.ID, _ change: LayerGeometryChange) {
        geometryChangeCount += 1
        lastGeometryChange = (id, change)
        switch change {
        case .removed: masks[id] = nil
        case .duplicated(let source): if masks[id] == nil { masks[id] = masks[source] }
        default:
            guard let mask = try? masks[id]?.flattened(), let at = index(of: id) else { return }
            masks[id] = TiledPixels(Self.moved(mask, change, layers[at], pixels[id]))
        }
    }

    /// `mask` of `layer` after `change`; the pixels are the layer's own after
    /// every change but a crop. A flip or a transform is PV-2's and PV-7's to follow.
    private static func moved(_ mask: PixelBuffer, _ change: LayerGeometryChange, _ layer: PhotoLayer,
                              _ pixels: TiledPixels?) -> PixelBuffer {
        switch change {
        case .cropped(let crop):
            // Merge Down sends its new bounds after the pixels changed: keep the mask the pixels' size.
            if let pixels, pixels.width != mask.width || pixels.height != mask.height { return fitted(mask, pixels) }
            let rect = PixelRect(x: layer.offsetX, y: layer.offsetY, width: mask.width, height: mask.height)
            guard let kept = rect.intersection(crop),
                  let cut = try? mask.cropped(x: kept.x - rect.x, y: kept.y - rect.y, width: kept.width, height: kept.height)
            else { return (try? PixelBuffer(width: 1, height: 1, fill: hidden)) ?? mask }
            return cut
        case .canvasResized(let dx, let dy):
            guard let pixels, pixels.width != mask.width || pixels.height != mask.height,
                  var grown = try? PixelBuffer(width: pixels.width, height: pixels.height, fill: shown),
                  (try? grown.composite(mask, x: dx, y: dy, mode: .normal, opacity: 1)) != nil else { return mask }
            return grown
        case .rotated(let turn): return fitted(mask.rotated(turn), pixels)
        case .straightened(let degrees, _):
            return fitted((try? mask.rotated(degrees: degrees, filter: .lanczos3)) ?? mask, pixels)
        default: return fitted(mask, pixels)
        }
    }

    /// `mask` resized to `pixels`' size when the two differ.
    private static func fitted(_ mask: PixelBuffer, _ pixels: TiledPixels?) -> PixelBuffer {
        guard let pixels, pixels.width != mask.width || pixels.height != mask.height else { return mask }
        return (try? mask.resized(width: pixels.width, height: pixels.height, filter: .bilinear)) ?? mask
    }

    static let shown = RGBA(r: 1, g: 1, b: 1, a: 1), hidden = RGBA(r: 0, g: 0, b: 0, a: 1)
}

/// What a new mask starts as: white (shows the whole layer), black (hides it) or the selection's coverage.
public enum MaskStart: String, Codable, CaseIterable, Sendable {
    case reveal, hide, selection
}

extension PhotoWorkspace {
    static let notImageLayer = "Select an image layer first.", noMask = "This layer has no mask."
    static let hasMaskAlready = "This layer already has a mask.", noSelection = "Make a selection first."

    /// Why Delete, Apply, Disable and Edit Mask can't act on the selected layer, or nil when they can.
    public var maskHelp: String? {
        guard canvas != nil else { return Self.noImage }
        guard let layer = selectedLayer, layer.kind == .pixels else { return Self.notImageLayer }
        guard layer.hasMask else { return Self.noMask }
        return nil
    }

    /// Why a mask starting as `start` can't be added to the selected layer, or nil when it can.
    public func addMaskHelp(_ start: MaskStart) -> String? {
        guard canvas != nil else { return Self.noImage }
        guard let layer = selectedLayer, layer.kind == .pixels else { return Self.notImageLayer }
        guard !layer.hasMask else { return Self.hasMaskAlready }
        if start == .selection, selection == nil, selectionMask == nil { return Self.noSelection }
        return nil
    }

    /// Adds a mask to the selected layer, starting as `start`, in one undo step.
    public mutating func addMask(_ start: MaskStart) throws {
        if let why = addMaskHelp(start) { throw PhotoRefusal(why) }
        guard let id = selectedLayerID, let at = index(of: id), let tiled = pixels[id] else { return }
        let layer = layers[at]
        var mask = try PixelBuffer(width: tiled.width, height: tiled.height, fill: start == .hide ? Self.hidden : Self.shown)
        if start == .selection {
            for y in 0..<mask.height {
                for x in 0..<mask.width {
                    let c = selectionCoverage(x: x + layer.offsetX, y: y + layer.offsetY)
                    try mask.setPixel(x: x, y: y, RGBA(r: c, g: c, b: c, a: 1))
                }
            }
        }
        record(.stack(stackState), named: "Add Layer Mask")
        masks[id] = TiledPixels(mask)
        layers[at].hasMask = true
        layers[at].isMaskEnabled = true
        touch(.all)
    }

    /// Deletes the selected layer's mask in one undo step.
    public mutating func deleteMask() throws {
        if let why = maskHelp { throw PhotoRefusal(why) }
        guard let id = selectedLayerID, let at = index(of: id) else { return }
        record(.stack(stackState), named: "Delete Layer Mask")
        dropMask(at)
    }

    /// Bakes the selected layer's mask into its pixels and drops the mask, in one undo step.
    public mutating func applyMask() throws {
        if let why = maskHelp { throw PhotoRefusal(why) }
        guard let id = selectedLayerID, let at = index(of: id), var buffer = try pixels[id]?.flattened() else { return }
        let mask = try masks[id]?.flattened()
        for y in 0..<buffer.height {
            for x in 0..<buffer.width {
                let c = (try? mask?.pixel(x: x, y: y).r) ?? 1
                let p = try buffer.pixel(x: x, y: y)
                try buffer.setPixel(x: x, y: y, RGBA(r: p.r * c, g: p.g * c, b: p.b * c, a: p.a * c))
            }
        }
        record(.stack(stackState), named: "Apply Layer Mask")
        pixels[id] = TiledPixels(buffer)
        dropMask(at)
    }

    /// Removes layer `at`'s mask and points the brush back at its pixels.
    private mutating func dropMask(_ at: Int) {
        masks[layers[at].id] = nil
        layers[at].hasMask = false
        layers[at].isMaskEnabled = true
        editsMask = false
        touch(.all)
    }

    /// Turns the selected layer's mask on or off, keeping it, in one undo step.
    public mutating func setMaskEnabled(_ enabled: Bool) throws {
        if let why = maskHelp { throw PhotoRefusal(why) }
        guard let id = selectedLayerID, let at = index(of: id), layers[at].isMaskEnabled != enabled else { return }
        recordLayers(named: enabled ? "Enable Layer Mask" : "Disable Layer Mask")
        layers[at].isMaskEnabled = enabled
        touch(.all)
    }

    /// Points the brush and eraser at the selected layer's mask (`on`) or its pixels. No undo step.
    public mutating func setEditsMask(_ on: Bool) {
        guard !on || maskHelp == nil else { return }
        editsMask = on
    }
}
