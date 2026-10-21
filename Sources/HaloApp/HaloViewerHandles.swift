// HaloViewerHandles.swift: SuiteUI's SelectionHandlesEditor over the selected
// layer in Halo's viewer (transform HT-2,
// docs/blueprints/halo/features/transform.md). The box and its turn are the
// Model's `transformSelection` (HaloTransform+Kernel.swift), from the live
// drag's project while one lasts (HaloLiveEdit) so the handles follow a move,
// laid out on the artboard's fitted frame as HaloViewerGestures is. Until
// HT-3 wires the handle drags, the handles are marks: they take no hits, so
// a press on them falls through to the viewer's move drag and nothing on
// screen is a dead control. Nothing selected draws nothing. It reads its
// model and never acts.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct HaloViewerHandles: View {
    let model: HaloProject
    @Environment(\.haloLiveEdit) private var live

    var body: some View {
        let shown = live?.project ?? model
        if let comp = shown.selectedComposition, let item = shown.transformSelection {
            let artboard = CGSize(width: max(comp.width, 1), height: max(comp.height, 1))
            GeometryReader { proxy in
                SelectionHandlesEditor(
                    rect: Self.rect(item), degrees: item.degrees,
                    zoom: Self.zoom(artboardWidth: Double(artboard.width), width: Double(proxy.size.width)),
                    onResize: { _ in }, onRotate: { _ in }, onEnd: {})
            }
            .allowsHitTesting(false)
            .aspectRatio(artboard, contentMode: .fit)
            .frame(maxWidth: artboard.width, maxHeight: artboard.height)
            .padding(SuiteSize.canvasInset)
        }
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
