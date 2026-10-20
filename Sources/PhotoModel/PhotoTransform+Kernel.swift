// PhotoTransform+Kernel.swift: Photo as SuiteKernel's TransformTarget
// (transform PT-1 contract, PT-5 bodies), and Free Transform's begin, commit
// and cancel, and Canvas Size. The box the kernel sees is the draft's box
// (scaled about its top-left and moved, turned about its centre), else the
// selected pixel layer's bounds, cut to the selection when one is set.
// A scale, turn or move edits the draft as one step whose undo puts the
// previous draft back (a drag's steps fold under its token); commit resamples
// the layer once as one "Free Transform" step; a flip mirrors the layer's
// pixels in place at once, never a draft. Canvas Size refuses until PT-6.
// Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace: TransformTarget {
    /// The draft's box while Free Transform is up, else the selected pixel
    /// layer's bounds (or the selection's part of it); nil with no pixel layer.
    public var transformSelection: TransformBox? {
        if let draft = transformDraft {
            let b = draft.box, t = draft.transform
            let (x, y) = (Double(b.x) + t.dx, Double(b.y) + t.dy)
            let box = Rect(minX: x, minY: y, maxX: x + Double(b.width) * t.scaleX, maxY: y + Double(b.height) * t.scaleY)
            return TransformBox(box: box, degrees: t.degrees)
        }
        guard let rect = transformBounds else { return nil }
        return TransformBox(box: Rect(minX: Double(rect.x), minY: Double(rect.y),
                                      maxX: Double(rect.x + rect.width), maxY: Double(rect.y + rect.height)))
    }

    /// Why Free Transform and the flips can't run: no pixel layer selected,
    /// else the transform service's help; nil when they can.
    public var transformHelp: String? {
        guard transformBounds != nil else { return "Select a pixel layer to transform." }
        return services.transform.unavailableHelp
    }

    /// A flip mirrors the layer's pixels at once, so not while a draft is up.
    public var flipHelp: String? {
        transformDraft == nil ? nil : "Press Return or Escape to finish Free Transform first."
    }

    /// Sets the selected layer's box as one step named `name` (a drag's steps
    /// fold under its token): a flip mirrors the layer in place at once; any
    /// other change edits the draft, beginning one when none is up.
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        if let help = transformHelp { throw PhotoRefusal(help) }
        guard let current = transformSelection else { return }
        if t.flipX != current.flipX || t.flipY != current.flipY {
            if let help = flipHelp { throw PhotoRefusal(help) }
            return try flipLayer(x: t.flipX != current.flipX, y: t.flipY != current.flipY, name: name)
        }
        let b = t.box
        guard b.width > 0, b.height > 0, [b.minX, b.minY, b.width, b.height, t.degrees].allSatisfy(\.isFinite) else {
            throw PhotoRefusal("The transformed box needs a width and height above 0.")
        }
        let previous = transformDraft
        guard let id = selectedLayerID, var draft = previous ?? transformBounds.map({ TransformDraft(layerID: id, box: $0) })
        else { return }
        let box = draft.box
        draft.transform = LayerTransform(
            scaleX: b.width / Double(box.width), scaleY: b.height / Double(box.height),
            degrees: t.degrees, dx: b.minX - Double(box.x), dy: b.minY - Double(box.y))
        guard draft != previous else { return }
        record(.draft(previous), named: name, coalescing: drag)
        transformDraft = draft
        touch(.all)
    }

    /// Mirrors the selected layer's pixels across their own centre lines, the
    /// layer staying where it is: one step named `name`.
    private mutating func flipLayer(x: Bool, y: Bool, name: String) throws {
        guard let id = selectedLayerID, let at = index(of: id), let tiles = pixels[id] else { return }
        var content = PlacedPixels(pixels: tiles, x: layers[at].offsetX, y: layers[at].offsetY)
        if x { content = try services.transform.flipped(content, .horizontal) }
        if y { content = try services.transform.flipped(content, .vertical) }
        record(.stack(stackState), named: name)
        pixels[id] = content.pixels
        layers[at].offsetX = content.x
        layers[at].offsetY = content.y
        touch(.all)
    }

    /// The box Free Transform starts from: the selected pixel layer's bounds,
    /// cut to the selection when one is set; nil without either.
    var transformBounds: PixelRect? {
        guard let layer = selectedLayer, layer.kind == .pixels, let bounds = bounds(of: layer), !bounds.isEmpty else {
            return nil
        }
        guard let selection else { return bounds }
        return selection.intersection(bounds)
    }
}

extension PhotoWorkspace {
    /// Edit > Free Transform: starts a draft on the selected pixel layer's box,
    /// no step. Throws the help when it can't; a draft already up stays.
    public mutating func beginTransform() throws {
        if let help = transformHelp { throw PhotoRefusal(help) }
        guard transformDraft == nil, let id = selectedLayerID, let box = transformBounds else { return }
        transformDraft = TransformDraft(layerID: id, box: box)
    }

    /// Return: resamples the layer once into its new bounds as one "Free
    /// Transform" step; the identity records nothing. No draft: nothing.
    /// A resample that fails keeps the draft and throws.
    public mutating func commitTransform() throws {
        guard let draft = transformDraft else { return }
        guard draft.transform != .identity, let at = index(of: draft.layerID), let tiles = pixels[draft.layerID] else {
            transformDraft = nil
            return touch(.all)
        }
        let content = PlacedPixels(pixels: tiles, x: layers[at].offsetX, y: layers[at].offsetY)
        let placed = try services.transform.applied(draft, to: content)
        record(.group([.stack(stackState), .draft(draft)]), named: "Free Transform")
        pixels[draft.layerID] = placed.pixels
        layers[at].offsetX = placed.x
        layers[at].offsetY = placed.y
        transformDraft = nil
        touch(.all)
    }

    /// Escape: drops the draft, no step. The draft's own steps stay, so Undo
    /// can walk back into them.
    public mutating func cancelTransform() {
        guard transformDraft != nil else { return }
        transformDraft = nil
        touch(.all)
    }

    /// Image > Canvas Size: grows or crops the canvas to `width` x `height`
    /// about `anchor` as one "Canvas Size" step. PT-1 stub: refuses until PT-6.
    public mutating func resizeCanvas(width: Int, height: Int, anchor: BoxAnchor) throws {
        guard canvas != nil else { throw RasterError.invalid("no image is open") }
        throw NotBuilt(feature: "PT-6").refuse()
    }
}
