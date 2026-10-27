// CanvasHostView+Lift.swift: the canvas host's live transform. A transform drag lifts the layer it moves off
// the picture: the app renders the picture once without that layer and hands the host the layer's pixels
// (`lift`), which show in one CALayer above the picture (tiles or Metal) and under the overlay. Each drag
// sample only sets that layer's affine transform in a transaction with actions off (`moveLift`), so the
// compositor moves pixels it already has and no pixel work runs per sample, as a browser moves a layer
// with a CSS transform. The release drops it (`dropLift`) in the turn the exact picture arrives; on the
// Metal path it stays until that picture's drawable is presented.
// A placement maps the lifted pixels (x right, y down from their top-left) to document pixels (y down); the
// host turns that into the container's unflipped space, so it zooms, pans and turns with the picture.
// Photo's Free Transform lifts; Design and Halo can adopt the same three calls. macOS only.
import AppKit
import QuartzCore

extension CanvasHostView {
    /// Lifts `contents` (an IOSurface or CGImage of `size` pixels) above the picture at `placement`, at
    /// `opacity`; a lift already up is replaced.
    public func lift(_ contents: Any, size: CGSize, opacity: Float, placement: CGAffineTransform) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        let layer = lifted ?? CALayer()
        layer.anchorPoint = .zero
        layer.position = .zero
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.contents = contents
        layer.opacity = opacity
        layer.magnificationFilter = tileFilter ?? .linear
        layer.minificationFilter = .trilinear
        layer.name = RenderingControlID.canvas + ".lift"
        if layer.superlayer == nil { liftSpace.addSublayer(layer) }
        lifted = layer
        layer.setAffineTransform(Self.liftTransform(placement, size: size, document: documentSize))
    }

    /// Moves the lifted layer to `placement`, with no animation; nothing with no lift up.
    public func moveLift(_ placement: CGAffineTransform) {
        guard let lifted else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        lifted.setAffineTransform(Self.liftTransform(placement, size: lifted.bounds.size, document: documentSize))
        CATransaction.commit()
    }

    /// Removes the lifted layer; nothing with no lift up. On the Metal path with a new picture still to
    /// present, it goes once that picture is on screen (`removeDroppedLift`), at most 0.25 s later.
    public func dropLift() {
        guard let lifted else { return }
        self.lifted = nil
        removeDroppedLift()
        droppedLift = lifted
        guard metalLayer != nil, pictureChanged else { return removeDroppedLift() }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            if self?.droppedLift === lifted { self?.removeDroppedLift() }
        }
    }

    /// Takes the dropped lift off the screen; nothing with none.
    func removeDroppedLift() {
        guard let gone = droppedLift else { return }
        droppedLift = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gone.removeFromSuperlayer()
        gone.contents = nil
        CATransaction.commit()
    }

    /// Whether a layer is lifted.
    public var isLifted: Bool { lifted != nil }

    /// The lifted layer's transform in the container's unflipped document space: its own unflipped points
    /// (y up) to its pixels (y down), through `placement`, then document rows to the container's (y up).
    nonisolated static func liftTransform(_ placement: CGAffineTransform, size: CGSize, document: CGSize) -> CGAffineTransform {
        let own = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height)
        let rows = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: document.height)
        return own.concatenating(placement).concatenating(rows)
    }
}
