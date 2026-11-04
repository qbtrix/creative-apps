// CanvasHostView+LiveLayer.swift: the canvas's live layer, the one way any canvas drag moves pixels while
// it lasts (render contract rule 3). On drag start the app renders its picture once without what the drag
// moves and hands that layer's pixels to the host (`showLiveLayer`, a CanvasLiveLayer: an IOSurface or
// CGImage, its size, its opacity, and an optional document-sized cover of what lies above it). They show in
// one CALayer above the picture (tiles or Metal) and under the overlay, the cover in one more over them that
// never moves. Each sample only sets that layer's affine transform in a transaction with actions off
// (`moveLiveLayer`), so the compositor moves pixels it already has and no pixel work runs per sample, as a
// browser moves a layer with a CSS transform. On commit or cancel the app draws the exact picture and drops
// the layer (`dropLiveLayer`) in the turn it arrives; on the Metal path it stays until that picture's
// drawable is presented, so the release never flashes the picture without it. A transform maps the layer's
// pixels (x right, y down from their top-left) to document pixels (y down); the host turns that into the
// container's unflipped space, so it zooms, pans and turns with the picture. A live layer that is all the
// picture shows can hide the picture until its drop (`hidingPicture`), so nothing renders an empty one. Nothing here knows the app or
// the gesture: a move, resize or rotate is just a transform. Photo's Free Transform is the first caller.
// macOS only.
import AppKit
import QuartzCore

/// Pixels a drag moves on the compositor: `contents` (an IOSurface or CGImage, premultiplied) of `size`
/// pixels, drawn at `opacity`, and an optional `cover`: document-sized premultiplied contents that stay put over
/// them (what lies above the moved pixels).
public struct CanvasLiveLayer {
    public let contents: Any
    public let size: CGSize
    public let opacity: Float
    public let cover: Any?

    public init(contents: Any, size: CGSize, opacity: Float = 1, cover: Any? = nil) {
        (self.contents, self.size, self.opacity, self.cover) = (contents, size, opacity, cover)
    }
}

extension CanvasHostView {
    /// Shows `live` above the picture at `transform` (its pixels to document pixels); one already up is replaced.
    /// `hidingPicture` when `live` is everything the picture shows: the picture hides until the drop, so the
    /// app needs no render of an empty picture under it.
    public func showLiveLayer(_ live: CanvasLiveLayer, at transform: CGAffineTransform, hidingPicture: Bool = false) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        if hidingPicture {
            container.isHidden = true
            metalLayer?.isHidden = true
            pictureHidden = true
        }
        let layer = lifted ?? CALayer()
        layer.anchorPoint = .zero
        layer.position = .zero
        layer.bounds = CGRect(origin: .zero, size: live.size)
        layer.contents = live.contents
        layer.opacity = live.opacity
        layer.magnificationFilter = tileFilter ?? .linear
        layer.minificationFilter = .trilinear
        layer.name = RenderingControlID.canvas + ".live-layer"
        if layer.superlayer == nil { liftSpace.addSublayer(layer) }
        lifted = layer
        layer.setAffineTransform(Self.liveTransform(transform, size: live.size, document: documentSize))
        showCover(live.cover)
    }

    /// Shows `contents` over the live layer at the document's place and size, or removes the cover for nil.
    private func showCover(_ contents: Any?) {
        guard let contents else {
            liftCover?.removeFromSuperlayer()
            liftCover = nil
            return
        }
        let cover = liftCover ?? CALayer()
        cover.anchorPoint = .zero
        cover.position = .zero
        cover.bounds = CGRect(origin: .zero, size: documentSize)
        cover.contents = contents
        cover.magnificationFilter = tileFilter ?? .linear
        cover.minificationFilter = .trilinear
        cover.name = RenderingControlID.canvas + ".live-cover"
        if cover.superlayer == nil { liftSpace.addSublayer(cover) }
        liftCover = cover
        cover.setAffineTransform(Self.liveTransform(.identity, size: documentSize, document: documentSize))
    }

    /// Moves the live layer to `transform`, with no animation; nothing with none up.
    public func moveLiveLayer(_ transform: CGAffineTransform) {
        guard let lifted else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lifted.setAffineTransform(Self.liveTransform(transform, size: lifted.bounds.size, document: documentSize))
        CATransaction.commit()
    }

    /// Removes the live layer (the drag committed or cancelled); nothing with none up. On the Metal path with
    /// a new picture still to present, it goes once that picture is on screen (`removeDroppedLift`), at most
    /// 0.25 s later.
    public func dropLiveLayer() {
        guard let lifted else { return }
        self.lifted = nil
        removeDroppedLift()
        (droppedLift, droppedCover, liftCover) = (lifted, liftCover, nil)
        guard metalLayer != nil, pictureChanged else { return removeDroppedLift() }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            if self?.droppedLift === lifted { self?.removeDroppedLift() }
        }
    }

    /// Whether a live layer is up.
    public var hasLiveLayer: Bool { lifted != nil }

    /// Takes the dropped live layer off the screen, showing a picture it hid; nothing with none.
    func removeDroppedLift() {
        guard let gone = droppedLift else { return }
        droppedLift = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gone.removeFromSuperlayer()
        gone.contents = nil
        droppedCover?.removeFromSuperlayer()
        droppedCover = nil
        if pictureHidden {
            container.isHidden = metalLayer != nil
            metalLayer?.isHidden = false
            pictureHidden = false
        }
        CATransaction.commit()
    }

    /// The live layer's transform in the container's unflipped document space: its own unflipped points
    /// (y up) to its pixels (y down), through `transform`, then document rows to the container's (y up).
    nonisolated static func liveTransform(_ transform: CGAffineTransform, size: CGSize, document: CGSize) -> CGAffineTransform {
        let own = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
        let rows = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: document.height)
        return own.concatenating(transform).concatenating(rows)
    }
}
