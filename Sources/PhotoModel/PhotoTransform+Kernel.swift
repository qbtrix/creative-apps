// PhotoTransform+Kernel.swift: Photo as SuiteKernel's TransformTarget
// (transform PT-1 contract, PT-5 bodies), and Free Transform's begin, commit
// and cancel. The box the kernel sees is the draft's box
// (scaled about its top-left and moved, turned about its centre), else the
// bounds of the selected pixel layer's painted pixels (alpha above 0), cut to
// the selection when one is set; a clear layer refuses "Nothing to transform.".
// Availability reads only `transformArea` (layer and selection, no pixel scan).
// A scale, turn or move edits the draft as one step whose undo puts the
// previous draft back (a drag's steps fold under its token). The canvas shows
// the draft live: a still frame draws `transformPreview`, the workspace with
// the draft's layer resampled (`draftPlaced`), and commit lays that same
// resample as one "Free Transform" step, so Return shows nothing new; a box on
// part of the layer keeps the layer's extent, so later strokes outside it still
// land. A drag whose layer lifts (PhotoTransformLift+Kernel.swift) draws no frames:
// the compositor moves the layer's pixels. Any other drag's frames
// (`transformPreview(live:)`) draw the layer through the draft's matrix region
// by region (PhotoRenderRoute.swift, bilinear); the exact frame follows at the release.
// A flip mirrors the layer's pixels in place at once, never a draft. Canvas
// Size is PhotoImageOps'. Linux-safe.
import CoreRaster
import SuiteKernel

extension PhotoWorkspace: TransformTarget {
    /// The draft's box while Free Transform is up, else the selected pixel
    /// layer's painted bounds (in the selection when one is set); nil with no
    /// pixel layer or nothing painted there.
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
        guard transformArea != nil else { return "Select a pixel layer to transform." }
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

    /// The box Free Transform starts from: the bounds of the selected pixel
    /// layer's pixels with alpha above 0 inside `transformArea`, on the canvas;
    /// nil without a pixel layer or when nothing is painted there.
    var transformBounds: PixelRect? {
        guard let layer = selectedLayer, let area = transformArea, let tiles = pixels[layer.id],
            let painted = try? tiles.paintedBounds(in: area.offsetBy(-layer.offsetX, -layer.offsetY))
        else { return nil }
        return painted.offsetBy(layer.offsetX, layer.offsetY)
    }

    /// Where Free Transform looks for pixels: the selected pixel layer's
    /// bounds, cut to the selection when one is set; nil without either.
    var transformArea: PixelRect? {
        guard let layer = selectedLayer, layer.kind == .pixels, let bounds = bounds(of: layer), !bounds.isEmpty else {
            return nil
        }
        guard let selection else { return bounds }
        return selection.intersection(bounds)
    }
}

extension PhotoWorkspace {
    /// Edit > Free Transform: starts a draft on the selected pixel layer's box,
    /// no step. Throws the help when it can't, "Nothing to transform." when no
    /// pixel there is painted; a draft already up stays.
    public mutating func beginTransform() throws {
        if let help = transformHelp { throw PhotoRefusal(help) }
        guard transformDraft == nil, let id = selectedLayerID else { return }
        guard let box = transformBounds else { throw PhotoRefusal("Nothing to transform.") }
        transformDraft = TransformDraft(layerID: id, box: box)
    }

    /// Return: resamples the layer once into its new bounds as one "Free
    /// Transform" step; a box on part of the layer keeps the layer's extent
    /// (grown to the new bounds). The identity records nothing. No draft: nothing.
    /// A resample that fails keeps the draft and throws.
    public mutating func commitTransform() throws {
        guard let draft = transformDraft else { return }
        guard let done = try draftPlaced() else {
            transformDraft = nil
            return touch(.all)
        }
        let at = done.at
        var placed = done.placed
        // A box on part of the layer (its painted pixels) keeps the layer's extent, so later strokes outside
        // the box still land: the placed pixels go, exactly, onto a clear layer over both bounds.
        if let was = bounds(of: layers[at]), draft.box != was {
            let all = was.union(PixelRect(x: placed.x, y: placed.y, width: placed.pixels.width,
                                          height: placed.pixels.height))
            var kept = try TiledPixels(width: all.width, height: all.height)
            try kept.replace(with: placed.pixels.flattened(), x: placed.x - all.x, y: placed.y - all.y)
            placed = PlacedPixels(pixels: kept, x: all.x, y: all.y)
        }
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

    /// The draft's layer resampled through the draft into its new bounds (`services.transform.applied`), with
    /// the layer's index: what Return lays and what the canvas previews. Nil with no draft, the identity, or a
    /// layer without pixels.
    func draftPlaced() throws -> (at: Int, placed: PlacedPixels)? {
        guard let draft = transformDraft, draft.transform != .identity, let at = index(of: draft.layerID),
            let tiles = pixels[draft.layerID]
        else { return nil }
        let content = PlacedPixels(pixels: tiles, x: layers[at].offsetX, y: layers[at].offsetY)
        PhotoRenderCount.resample()
        return (at, try services.transform.applied(draft, to: content))
    }

    /// The workspace as the canvas shows it while Free Transform is up: the draft's layer swapped for
    /// `draftPlaced()`, so every route draws the draft and Return lays the same pixels. The revision and
    /// history stay as they are. Self with no draft, and when the resample fails (the layer shows as it is,
    /// and Return reports the failure).
    var transformPreview: PhotoWorkspace {
        guard let done = (try? draftPlaced()) ?? nil else { return self }
        let (at, placed) = done
        var shown = self
        shown.pixels[layers[at].id] = placed.pixels
        shown.layers[at].offsetX = placed.x
        shown.layers[at].offsetY = placed.y
        return shown
    }

    /// `transformPreview` for a still frame; for a drag frame (`live`), self with `liveDraft` set, so every route
    /// draws the draft's layer through its matrix on each region and nothing resamples (the exact frame comes
    /// with the next still one). A masked layer, the identity and a layer without pixels take the still frame.
    /// A layer that lifts (`liftKey`) never comes here mid-drag: the compositor moves its pixels.
    /// ponytail: a drag frame resamples the layer in 256 px chunks on the CPU (bilinear, the chunks across the cores); a
    /// Metal `.affine` kernel is the upgrade for the layers that can't lift.
    func transformPreview(live: Bool) -> PhotoWorkspace {
        guard live, let draft = transformDraft, draft.transform != .identity, let at = index(of: draft.layerID),
            pixels[draft.layerID] != nil, shownMask(of: layers[at]) == nil
        else { return transformPreview }
        var shown = self
        shown.liveDraft = true
        return shown
    }

    /// The layer a drag frame draws through the draft's matrix; nil outside a drag frame.
    var liveDraftLayer: PhotoLayer.ID? { liveDraft ? transformDraft?.layerID : nil }
}
