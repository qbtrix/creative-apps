// HaloViewerGestures.swift: the viewer's pointer input over the artboard
// (#207, LK-11). A clear, hit-testable view laid out on the artboard's fitted
// frame, the way HaloViewerCanvas lays out its layers, so the surround around
// it takes no hits. A drag (minimum distance 0) maps its points through the
// Model's `compositionPoint` and sends `beginViewerDrag` at its start, then
// `moveViewerDrag` on each change and `endViewerDrag` on release; the Model
// hits, previews and records. A click focuses it, so Escape sends
// `cancelViewerDrag`. It is hidden from accessibility: the artboard element
// (`halo.viewer`) around it names it. It reads its model and never assigns it.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloViewerGestures: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    /// The artboard's size in points, for the mapping to composition pixels.
    @State private var size = CGSize.zero
    /// Whether this drag already sent its begin.
    @State private var dragging = false

    var body: some View {
        let comp = model.selectedComposition
        let artboard = CGSize(width: max(comp?.width ?? 1, 1), height: max(comp?.height ?? 1, 1))
        Color.clear
            .aspectRatio(artboard, contentMode: .fit)
            .frame(maxWidth: artboard.width, maxHeight: artboard.height)
            .contentShape(Rectangle())
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .gesture(drag)
            .focusable()
            .focusEffectDisabled()
            .onExitCommand { perform(.cancelViewerDrag) }
            .accessibilityHidden(true)
            .padding(SuiteSize.canvasInset)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !dragging {
                    dragging = true
                    if let start = point(value.startLocation) { perform(.beginViewerDrag(x: start.x, y: start.y)) }
                }
                if let now = point(value.location) { perform(.moveViewerDrag(x: now.x, y: now.y)) }
            }
            .onEnded { _ in
                dragging = false
                perform(.endViewerDrag)
            }
    }

    /// `location` in the artboard's points as composition pixels; nil before
    /// the artboard has a size or with no composition.
    private func point(_ location: CGPoint) -> (x: Double, y: Double)? {
        guard let p = model.compositionPoint(
            x: Double(location.x), y: Double(location.y),
            artboardWidth: Double(size.width), artboardHeight: Double(size.height))
        else { return nil }
        return (p.x, p.y)
    }
}
