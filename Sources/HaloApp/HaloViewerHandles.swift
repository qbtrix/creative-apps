// HaloViewerHandles.swift: SuiteUI's SelectionHandlesEditor over the selected
// layer in Halo's viewer (transform HT-2 and HT-3,
// docs/blueprints/halo/features/transform.md). The box and its turn are the
// Model's `transformSelection` (HaloTransform+Kernel.swift), from the live
// drag's project while one lasts (HaloLiveEdit) so the handles follow a move,
// laid out on the artboard's fitted frame as HaloViewerGestures is. Only the
// handles and the rotate zones take hits; a press inside the box falls
// through to the viewer's move drag. A handle or knob drag keeps one
// HaloHandleDrag: each sample's step ("Scale" for a handle, "Rotate" for the
// knob, the turn so far from the press) is shown through the window's
// HaloLiveEdit as the window's project with `setTransform` applied to a copy,
// so the window's body doesn't run per sample; the release hands the last step
// once to `haloCommitTransform`, which the window (HaloWindow+Viewer.swift)
// sends to the Model as one step. Hosted without a HaloLiveEdit, nothing
// shows until the release. The first sample
// focuses the handles, so Escape drops the step and the preview, and the rest
// of that drag shows and commits nothing. Nothing selected draws nothing. It
// reads its model and never assigns it.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI

extension EnvironmentValues {
    /// Hands a handle drag's release to the window, which sends it to the
    /// Model's `setTransform` as one step; nil outside a HaloWindow.
    @Entry var haloCommitTransform: (@MainActor (TransformBox, String) -> Void)?
}

struct HaloViewerHandles: View {
    let model: HaloProject
    @State private var drag = HaloHandleDrag()
    @FocusState private var focused: Bool
    @Environment(\.haloLiveEdit) private var live
    @Environment(\.haloCommitTransform) private var commit
    @Environment(\.haloViewerTakesActivationClicks) private var takesActivationClicks

    var body: some View {
        let shown = live?.shown(model) ?? model
        if let comp = shown.selectedComposition, let item = shown.transformSelection {
            let artboard = CGSize(width: max(comp.width, 1), height: max(comp.height, 1))
            GeometryReader { proxy in
                SelectionHandlesEditor(
                    rect: Self.rect(item), degrees: item.degrees,
                    zoom: Self.zoom(artboardWidth: Double(artboard.width), width: Double(proxy.size.width)),
                    onResize: { show(drag.resized($0, from: model.transformSelection ?? item)) },
                    onRotate: { show(drag.turned($0, from: model.transformSelection ?? item)) },
                    onEnd: end)
            }
            .allowsWindowActivationEvents(takesActivationClicks)
            .aspectRatio(artboard, contentMode: .fit)
            .frame(maxWidth: artboard.width, maxHeight: artboard.height)
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onExitCommand {
                drag.cancel()
                live?.project = nil
            }
            .padding(SuiteSize.canvasInset)
        }
    }

    private func show(_ step: HaloHandleStep?) {
        if !focused { focused = true }
        HaloHandleDrag.show(step, in: live)
    }

    private func end() {
        if let step = drag.end() { commit?(step.box, step.name) }
        live?.project = nil
    }

    /// The box in composition pixels, as the handles take it.
    nonisolated static func rect(_ item: TransformBox) -> CGRect {
        let b = item.box
        return CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height)
    }

    /// Points per composition pixel on the fitted artboard; 1 when either width is 0.
    nonisolated static func zoom(artboardWidth: Double, width: Double) -> Double {
        guard artboardWidth > 0 else { return 1 }
        let s = width / artboardWidth
        return s.isFinite && s > 0 ? s : 1
    }
}

/// One step a handle drag would commit: the box and the undo name.
struct HaloHandleStep: Equatable, Sendable {
    let box: TransformBox
    let name: String
}

/// One handle drag: the box at its first sample, the step it would commit,
/// and whether Escape dropped it. `end()` hands the step over once and starts
/// the next drag clean.
struct HaloHandleDrag: Equatable, Sendable {
    private(set) var start: TransformBox?
    private(set) var step: HaloHandleStep?
    private(set) var cancelled = false

    /// A handle's resized box (composition pixels) as a "Scale" step keeping
    /// the turn and mirrors; a box under 1 pixel or not finite keeps the last step.
    mutating func resized(_ rect: CGRect, from item: TransformBox) -> HaloHandleStep? {
        guard !cancelled else { return nil }
        let base = start ?? item
        start = base
        let r = rect.standardized
        guard [r.minX, r.minY, r.maxX, r.maxY].allSatisfy(\.isFinite), r.width >= 1, r.height >= 1 else { return step }
        let box = Rect(minX: Double(r.minX), minY: Double(r.minY), maxX: Double(r.maxX), maxY: Double(r.maxY))
        step = HaloHandleStep(box: TransformBox(box: box, degrees: base.degrees, flipX: base.flipX, flipY: base.flipY),
                              name: "Scale")
        return step
    }

    /// The knob's turn so far (degrees from the press) as a "Rotate" step on the box at the press.
    mutating func turned(_ degrees: Double, from item: TransformBox) -> HaloHandleStep? {
        guard !cancelled else { return nil }
        let base = start ?? item
        start = base
        step = HaloHandleStep(box: TransformRules.rotated(base, by: degrees), name: "Rotate")
        return step
    }

    /// The release: the step to commit, nil after Escape or with none; the next drag starts clean.
    mutating func end() -> HaloHandleStep? {
        defer { self = HaloHandleDrag() }
        return cancelled ? nil : step
    }

    /// Escape: a live drag shows and commits nothing more until its release; nothing when idle.
    mutating func cancel() {
        guard start != nil else { return }
        cancelled = true
        step = nil
    }

    /// Shows `step` as the window's project with it applied; nothing without a step or a live edit.
    @MainActor static func show(_ step: HaloHandleStep?, in live: HaloLiveEdit?) {
        guard let step, let live else { return }
        live.show { try? $0.setTransform(step.box, name: step.name, drag: nil) }
    }
}
