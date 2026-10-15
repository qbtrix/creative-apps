// HaloViewer.swift: Halo's main content, the composition viewer with its
// status bar and timeline strip (HaloTimelineView), which scrubs the playhead
// and sets in and out points. HaloWindow builds it as `init(model:perform:)`,
// so every action is a HaloCommand. Views only read HaloProject and call its
// methods; all state lives in HaloModel (scripts/ci checks this).
import HaloModel
import SuiteUI
import SwiftUI

/// The main content: the composition viewer over a status bar of its zoom,
/// size, playhead timecode and layer count, then the timeline strip
/// (HaloTimelineView), or the empty state.
struct HaloViewer: View {
    let model: HaloProject
    var onNew: @MainActor () -> Void = {}
    var onScrub: @MainActor (Int) -> Void = { _ in }
    var onSelectLayer: @MainActor (HaloLayer.ID) -> Void = { _ in }
    var onSetInPoint: @MainActor () -> Void = {}
    var onSetOutPoint: @MainActor () -> Void = {}
    /// The viewer's size, for the zoom CanvasSurface fits the artboard at.
    @State private var viewport = CGSize.zero

    var body: some View {
        if let comp = model.selectedComposition {
            let artboard = CGSize(width: comp.width, height: comp.height)
            VStack(spacing: 0) {
                CanvasSurface(artboard: artboard)
                    .onGeometryChange(for: CGSize.self) { $0.size } action: { viewport = $0 }
                ViewerStatusBar(zoom: ViewerZoom.fitScale(artboard: artboard, in: viewport), size: comp.sizeText) {
                    Text(comp.statusTimecode)
                    Text(comp.layerSummary)
                }
                Divider()
                HaloTimelineView(
                    composition: comp, rows: model.timelineRows, onScrub: onScrub, onSelectLayer: onSelectLayer,
                    onSetInPoint: onSetInPoint, onSetOutPoint: onSetOutPoint)
            }
        } else {
            EmptyStateView(
                "No Composition", systemImage: "sparkles.rectangle.stack",
                message: "Create a composition to layer and animate footage, shapes and text.",
                action: ToolbarAction("New Composition…", systemImage: "plus", perform: onNew))
        }
    }
}

extension HaloViewer {
    /// The slot form HaloWindow builds: every action is a command sent to `perform`.
    init(model: HaloProject, perform: @escaping @MainActor (HaloCommand) -> Void) {
        self.init(
            model: model, onNew: { perform(.newComposition) }, onScrub: { perform(.scrub($0)) },
            onSelectLayer: { perform(.selectLayer($0)) }, onSetInPoint: { perform(.setInPoint) },
            onSetOutPoint: { perform(.setOutPoint) })
    }
}
