// PhotoTransform+Kernel.swift: Photo as SuiteKernel's TransformTarget
// (transform PT-1 contract, PT-5 bodies), and Free Transform's begin, commit
// and cancel, and Canvas Size. The box the kernel sees is the draft's box
// (scaled about its top-left and moved, turned about its centre), else the
// selected pixel layer's bounds, cut to the selection when one is set.
// On PT-1's stubs Begin starts the draft and Cancel drops it, so the window is
// clickable on the fakes (contract rule 18); every edit refuses with its task's
// NotBuilt help until PT-5 and PT-6 fill it in. Linux-safe.
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

    /// Sets the selected layer's box as one step named `name` (a drag's steps
    /// fold under its token): a draft edit while Free Transform is up, a flip
    /// at once. PT-1 stub: refuses until PT-5.
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        if let help = transformHelp { throw PhotoRefusal(help) }
        throw NotBuilt(feature: "PT-5").refuse()
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
    /// PT-1 stub: refuses until PT-5, keeping the draft.
    public mutating func commitTransform() throws {
        guard transformDraft != nil else { return }
        throw NotBuilt(feature: "PT-5").refuse()
    }

    /// Escape: drops the draft, no step.
    public mutating func cancelTransform() {
        transformDraft = nil
    }

    /// Image > Canvas Size: grows or crops the canvas to `width` x `height`
    /// about `anchor` as one "Canvas Size" step. PT-1 stub: refuses until PT-6.
    public mutating func resizeCanvas(width: Int, height: Int, anchor: BoxAnchor) throws {
        guard canvas != nil else { throw RasterError.invalid("no image is open") }
        throw NotBuilt(feature: "PT-6").refuse()
    }
}
