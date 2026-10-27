// PhotoTransformLift+Kernel.swift: what a Free Transform drag lifts off the canvas so the compositor moves it
// (SuiteUI's CanvasLiveLayer): the draft layer's pixels in the draft's box as premultiplied sRGB bytes, and
// the workspace without that layer, rendered once as the picture under it. Each drag sample then only places
// those pixels through the draft's matrix (`liftPlacement`); no pixel work runs until the release draws the
// exact frame, the resample Return lays. A layer lifts only when the compositor's plain over draws it as the
// canvas would (`liftKey`): a visible, unmasked, unstyled pixel layer at normal blend and opacity in 0...1, with
// no visible layer above it and the image's adjustments at identity, and a box no wider or taller than 16384
// px (the GPU's texture limit). Anything else draws through the matrix region by region
// (`transformPreview(live:)`). The lift shows pixels outside the box gone, as commit does. The pixels are the
// same for every drag of one draft (`liftSprite`), so the canvas makes them once per Free Transform; each drag
// renders only the picture under them (`liftedBase`). Linux-safe.
import CoreRaster

/// The draft's layer lifted off the canvas for a drag.
public struct PhotoTransformLift: Sendable {
    /// Which lift a drag sample belongs to: a new layer or box lifts again.
    public struct Key: Sendable, Equatable {
        public let layerID: PhotoLayer.ID
        public let box: PixelRect
    }

    /// What the lifted pixels are made of: the layer and box (`key`), the layer's opacity and its pixels. Equal
    /// while the same pixels would lift, so one sprite serves every drag of a draft: the pixels are the
    /// untransformed layer in the draft's box, which no drag changes. The pixels compare by storage first
    /// (an unchanged layer shares it), so a check is cheap.
    public struct Sprite: Sendable, Equatable {
        public let key: Key
        public let opacity: Double
        let source: TiledPixels
    }

    public let key: Key
    /// The workspace without the lifted layer, no draft: the picture under the lift, rendered once.
    public let base: PhotoWorkspace
    /// The lifted pixels' size.
    public let width: Int, height: Int
    /// width x height x 4 bytes, row-major, sRGB, premultiplied alpha (what the compositor draws as it is).
    public let rgba8: [UInt8]
    /// The layer's opacity, which the compositor applies.
    public let opacity: Double
}

extension PhotoWorkspace {
    /// The largest side a lift takes, the GPU's texture limit.
    static let liftLimit = 16384

    /// The lift a drag of the draft makes; nil without a draft, or when the compositor can't draw the
    /// layer as the canvas does.
    public var liftKey: PhotoTransformLift.Key? {
        guard let (at, part) = liftPart else { return nil }
        return PhotoTransformLift.Key(layerID: layers[at].id, box: part.offsetBy(layers[at].offsetX, layers[at].offsetY))
    }

    /// The lifted pixels' place on the canvas: their pixel (x right, y down from the top-left) to the canvas
    /// pixel the draft puts it at. Nil when nothing lifts.
    public var liftPlacement: AffineMatrix? {
        guard let (at, part) = liftPart, let draft = transformDraft,
            var m = try? services.transform.matrix(draft, origin: (layers[at].offsetX, layers[at].offsetY))
        else { return nil }
        (m.tx, m.ty) = (m.tx + m.a * Double(part.x) + m.c * Double(part.y), m.ty + m.b * Double(part.x) + m.d * Double(part.y))
        return m
    }

    /// The lift for the draft as it is; nil when nothing lifts. Reads the layer's pixels in the box once.
    public func lifted() throws -> PhotoTransformLift? {
        guard let key = liftKey, let base = liftedBase, let sprite = try liftedPixels() else { return nil }
        return PhotoTransformLift(key: key, base: base, width: sprite.width, height: sprite.height, rgba8: sprite.rgba8,
                                  opacity: sprite.opacity)
    }

    /// What the draft's lift is made of (PhotoTransformLift.Sprite); nil when nothing lifts.
    public var liftSprite: PhotoTransformLift.Sprite? {
        guard let key = liftKey, let (at, _) = liftPart, let tiles = pixels[key.layerID] else { return nil }
        return PhotoTransformLift.Sprite(key: key, opacity: layers[at].opacity, source: tiles)
    }

    /// The workspace without the draft's layer, no draft: the picture under the lift; nil when nothing lifts.
    public var liftedBase: PhotoWorkspace? {
        guard let (at, _) = liftPart else { return nil }
        var base = self
        base.transformDraft = nil
        base.liveDraft = false
        base.layers[at].isVisible = false
        return base
    }

    /// The lifted pixels: the layer in the draft's box as premultiplied sRGB bytes, and the layer's opacity;
    /// nil when nothing lifts. Reads the layer's pixels once: a drag reuses them while `liftSprite` holds.
    public func liftedPixels() throws -> (width: Int, height: Int, rgba8: [UInt8], opacity: Double)? {
        guard let (at, part) = liftPart, let tiles = pixels[layers[at].id] else { return nil }
        let whole = PixelRect(x: 0, y: 0, width: tiles.width, height: tiles.height)
        var bytes = try part == whole ? tiles.rgba8() : TiledPixels(tiles.flattened(part)).rgba8()
        PhotoRenderer.premultiply(&bytes)
        return (part.width, part.height, bytes, layers[at].opacity)
    }

    /// The draft layer's index and the part of its pixels in the draft's box (layer pixels), when it lifts.
    private var liftPart: (Int, PixelRect)? {
        guard let draft = transformDraft, adjustments.isIdentity, let at = index(of: draft.layerID),
            layers[..<at].allSatisfy({ !$0.isVisible })
        else { return nil }
        let layer = layers[at]
        guard layer.kind == .pixels, layer.isVisible, layer.blendMode == .normal, layer.style == .none,
            (0...1).contains(layer.opacity), shownMask(of: layer) == nil, let tiles = pixels[layer.id],
            let part = draft.box.offsetBy(-layer.offsetX, -layer.offsetY)
                .intersection(PixelRect(x: 0, y: 0, width: tiles.width, height: tiles.height)),
            part.width <= Self.liftLimit, part.height <= Self.liftLimit
        else { return nil }
        return (at, part)
    }
}
