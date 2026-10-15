// HaloViewerCanvas.swift: the artboard in Halo's viewer: CanvasSurface sized
// to the selected composition, the frame Render Frame shows
// (HaloRenderedFrameView) and the viewer's gestures (HaloViewerGestures) over
// it. Its accessibility value is the Model's `viewerSummary` ("Frame 30:
// Background, Badge, Title: Hello Halo"). viewer-playback (#37) replaces this
// body to draw `viewerDrawList`; the call site stays `init(model:perform:)`.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloViewerCanvas: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        let comp = model.selectedComposition
        CanvasSurface(artboard: CGSize(width: comp?.width ?? 1, height: comp?.height ?? 1))
            .overlay { HaloRenderedFrameView(model: model, perform: perform) }
            .overlay { HaloViewerGestures(model: model, perform: perform) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Artboard")
            .accessibilityValue(model.viewerSummary)
            .accessibilityIdentifier("halo.viewer")
    }
}
