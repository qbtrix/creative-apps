// PhotoTransformLift+Kernel.swift: what a Free Transform drag lifts off the canvas so the compositor moves it
// (SuiteUI's CanvasLiveLayer): the draft layer's pixels in the draft's box as premultiplied sRGB bytes, and
// the workspace without that layer, rendered once as the picture under it. Each drag sample then only places
// those pixels through the draft's matrix (`liftPlacement`); no pixel work runs until the release draws the
// exact frame, the resample Return lays. A layer lifts only when the compositor's plain overs draw it as the
// canvas would (`liftKey`): a visible, unmasked, unstyled pixel layer at normal blend and opacity in 0...1, whose
// visible layers above are all at normal blend and opacity in 0...1 (an adjustment layer among them unmasked),
// and a box no wider or taller than 16384 px with its margin (the GPU's texture limit).
// Anything else draws through the matrix region by region (`transformPreview(live:)`). The pixel layers above
// render once, canvas-sized, as the cover the compositor lays over the lift (`liftedCover`). The adjustment
// layers above, then the image's adjustments, tone the lifted pixels; the picture under the lift keeps both, and
// the cover the ones over its layers. Each toned on its own matches the canvas wherever the lift and the cover
// are opaque or clear (their soft edges blend toned colours until the release draws the exact frame). A blur or
// sharpen on the image or an adjustment layer above reads `readMargin` pixels around each pixel, so the lifted
// pixels carry those margins, summed, clear on every side, and blur alone: the lift's edge softens over the
// blurred picture under it, close to the canvas and exact again at the release. The picture under the lift keeps the layer's pixels outside the box
// (`boxCut`), as commit does, and lacks the layers above. The pixels are the same for every drag of one draft
// (`liftSprite`), so the canvas makes them once per Free Transform; each drag renders only the picture under
// them (`liftedBase`). Linux-safe.
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
        /// What tones the pixels, and the visible layers above with their pixels (the cover's makings).
        let adjustments: AdjustmentSettings
        let above: [PhotoLayer]
        let abovePixels: [TiledPixels?]
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
    /// The visible layers above, canvas-sized premultiplied sRGB bytes the compositor lays over the lift; nil
    /// with none.
    public let cover: [UInt8]?
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
        // Lifted pixel (0, 0) is layer pixel (part.x - margin, part.y - margin).
        let margin = liftMargin(above: at)
        let (x, y) = (Double(part.x - margin), Double(part.y - margin))
        (m.tx, m.ty) = (m.tx + m.a * x + m.c * y, m.ty + m.b * x + m.d * y)
        return m
    }

    /// The lift for the draft as it is; nil when nothing lifts. Reads the layer's pixels in the box once.
    public func lifted() throws -> PhotoTransformLift? {
        guard let key = liftKey, let base = liftedBase, let sprite = try liftedPixels() else { return nil }
        return PhotoTransformLift(key: key, base: base, width: sprite.width, height: sprite.height, rgba8: sprite.rgba8,
                                  opacity: sprite.opacity, cover: try liftedCover())
    }

    /// What the draft's lift is made of (PhotoTransformLift.Sprite); nil when nothing lifts.
    public var liftSprite: PhotoTransformLift.Sprite? {
        guard let key = liftKey, let (at, _) = liftPart, let tiles = pixels[key.layerID] else { return nil }
        let above = layers[..<at].filter(\.isVisible)
        return PhotoTransformLift.Sprite(key: key, opacity: layers[at].opacity, source: tiles, adjustments: adjustments,
                                         above: above, abovePixels: above.map { pixels[$0.id] })
    }

    /// The workspace without the draft's box and the layers above, no draft: the picture under the lift (the
    /// layer's pixels outside the box stay); nil when nothing lifts.
    public var liftedBase: PhotoWorkspace? {
        guard let (at, _) = liftPart else { return nil }
        var base = self
        base.transformDraft = nil
        base.liveDraft = false
        for above in 0...at where !base.layers[above].kind.isAdjustment { base.layers[above].isVisible = false }
        if let draft = transformDraft, let (_, rest) = try? boxCut(of: layers[at], in: draft.box) {
            base.pixels[layers[at].id] = rest
            base.layers[at].isVisible = true
        }
        return base
    }

    /// Whether the lifted layer is all the canvas shows: no other visible layer and the whole layer lifts, so the
    /// picture under it is empty.
    public var liftsAlone: Bool {
        guard let (at, part) = liftPart, let tiles = pixels[layers[at].id],
            part == PixelRect(x: 0, y: 0, width: tiles.width, height: tiles.height)
        else { return false }
        return layers.indices.allSatisfy { $0 == at || !layers[$0].isVisible }
    }

    /// The lifted pixels: the layer in the draft's box with the image's read margin around it, toned by the
    /// adjustment layers above and then the image's adjustments, as premultiplied sRGB bytes, and the layer's
    /// opacity; nil when nothing lifts. Reads the layer's pixels once: a drag reuses them while `liftSprite` holds.
    public func liftedPixels() throws -> (width: Int, height: Int, rgba8: [UInt8], opacity: Double)? {
        guard let (at, part) = liftPart, let tiles = pixels[layers[at].id] else { return nil }
        let whole = PixelRect(x: 0, y: 0, width: tiles.width, height: tiles.height)
        let tones = layers[..<at].reversed().filter { $0.isVisible && $0.opacity > 0 && $0.kind.isAdjustment }
        let margin = liftMargin(above: at)
        var bytes: [UInt8]
        if adjustments.isIdentity && tones.isEmpty {
            bytes = try part == whole ? tiles.rgba8() : TiledPixels(tiles.flattened(part)).rgba8()
        } else {
            var sprite = try tiles.flattened(part)
            if margin > 0 {
                var padded = try TiledPixels(width: part.width + 2 * margin, height: part.height + 2 * margin)
                try padded.replace(with: sprite, x: margin, y: margin)
                sprite = try padded.flattened()
            }
            for tone in tones {
                guard case .adjustment(let settings) = tone.kind else { continue }
                sprite = try services.adjustmentLayers.applying(settings, to: sprite, opacity: tone.opacity,
                                                                blendMode: tone.blendMode, mask: nil)
            }
            bytes = try TiledPixels(adjustments.applied(to: sprite)).rgba8()
        }
        PhotoRenderer.premultiply(&bytes)
        return (part.width + 2 * margin, part.height + 2 * margin, bytes, layers[at].opacity)
    }

    /// The cover: the visible layers above the lifted one, composited and toned alone, canvas-sized premultiplied
    /// sRGB bytes; nil when nothing lifts or no visible pixel layer is above it.
    public func liftedCover() throws -> [UInt8]? {
        guard let (at, _) = liftPart, layers[..<at].contains(where: { $0.isVisible && !$0.kind.isAdjustment }) else { return nil }
        var cover = self
        cover.transformDraft = nil
        cover.liveDraft = false
        for below in at..<layers.count { cover.layers[below].isVisible = false }
        var bytes = try TiledPixels(cover.composite()).rgba8()
        PhotoRenderer.premultiply(&bytes)
        return bytes
    }

    /// The draft layer's index and the part of its pixels in the draft's box (layer pixels), when it lifts.
    private var liftPart: (Int, PixelRect)? {
        guard let draft = transformDraft, let at = index(of: draft.layerID),
            layers[..<at].allSatisfy({ !$0.isVisible || covers($0) })
        else { return nil }
        let layer = layers[at]
        guard layer.kind == .pixels, layer.isVisible, layer.blendMode == .normal, layer.style == .none,
            (0...1).contains(layer.opacity), shownMask(of: layer) == nil, let tiles = pixels[layer.id],
            let part = draft.box.offsetBy(-layer.offsetX, -layer.offsetY)
                .intersection(PixelRect(x: 0, y: 0, width: tiles.width, height: tiles.height)),
            part.width + 2 * liftMargin(above: at) <= Self.liftLimit, part.height + 2 * liftMargin(above: at) <= Self.liftLimit
        else { return nil }
        return (at, part)
    }

    /// Whether a visible layer above the lift composites over it as a plain over, so it can ride as the cover, or
    /// is an unmasked adjustment layer, so it tones the lift (a mask holds the tone to its own part of the canvas,
    /// which the lift moves under).
    private func covers(_ layer: PhotoLayer) -> Bool {
        if layer.kind.isAdjustment, shownMask(of: layer) != nil { return false }
        return layer.blendMode == .normal && (0...1).contains(layer.opacity)
    }

    /// The clear margin the lifted pixels carry on every side: the image's read margin plus each visible
    /// adjustment layer's above the layer at `at`, as the blurs widen it one after another.
    private func liftMargin(above at: Int) -> Int {
        layers[..<at].reduce(adjustments.readMargin) { margin, layer in
            guard layer.isVisible, layer.opacity > 0, case .adjustment(let settings) = layer.kind else { return margin }
            return margin + settings.readMargin
        }
    }
}

extension PhotoLayerKind {
    /// Whether this is an adjustment layer, which tones what is under it instead of drawing.
    fileprivate var isAdjustment: Bool {
        if case .adjustment = self { return true }
        return false
    }
}
