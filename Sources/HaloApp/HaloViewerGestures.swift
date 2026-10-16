// HaloViewerGestures.swift: the viewer's pointer input over the artboard
// (#207, LK-11). A clear, hit-testable view laid out on the artboard's fitted
// frame, the way HaloViewerCanvas lays out its layers, so the surround around
// it takes no hits and its points map through the Model's `compositionPoint`
// at the artboard's own size. A drag (minimum distance 0) sends
// `beginViewerDrag` at its start, which hits and selects. Its moves go to the
// window's HaloLiveEdit as the window's project with that move applied
// (`moveViewerDrag` on a copy), so only the drawn layers re-run per sample;
// the release sends the last `moveViewerDrag` and `endViewerDrag`, and the
// Model records one "Move". Hosted without a HaloLiveEdit, each move is sent
// as it comes. A click focuses it, so Escape sends `cancelViewerDrag` and
// drops the live preview. It is hidden from accessibility: the artboard
// element (`halo.viewer`) around it names it. It reads its model and never
// assigns it.
import HaloModel
import SuiteUI
import SwiftUI

extension EnvironmentValues {
    /// Whether a press that activates the window also starts a drag; false
    /// in the app. A hosted-window test sets it, since a test can't make its
    /// app active.
    @Entry var haloViewerTakesActivationClicks = false
}

struct HaloViewerGestures: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    /// The artboard's size in points, for the mapping to composition pixels.
    @State private var size = CGSize.zero
    /// Whether this drag already sent its begin.
    @State private var dragging = false
    /// The press and the latest move, in composition pixels; nil with no drag
    /// or after Escape.
    @State private var start: HaloPoint?
    @State private var last: HaloPoint?
    @Environment(\.haloLiveEdit) private var live
    @Environment(\.haloViewerTakesActivationClicks) private var takesActivationClicks

    var body: some View {
        let comp = model.selectedComposition
        let artboard = CGSize(width: max(comp?.width ?? 1, 1), height: max(comp?.height ?? 1, 1))
        // The hit shape, the measured size and the gesture's points are the
        // fitted artboard's, not the frame's: the frame is as big as the
        // viewer, so measuring it stretched the mapping and missed layers.
        Color.clear
            .contentShape(Rectangle())
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .gesture(drag)
            .allowsWindowActivationEvents(takesActivationClicks)
            .aspectRatio(artboard, contentMode: .fit)
            .frame(maxWidth: artboard.width, maxHeight: artboard.height)
            .focusable()
            .focusEffectDisabled()
            .onExitCommand {
                (start, last) = (nil, nil)
                live?.project = nil
                perform(.cancelViewerDrag)
            }
            .accessibilityHidden(true)
            .padding(SuiteSize.canvasInset)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !dragging {
                    dragging = true
                    start = point(value.startLocation)
                    if let start { perform(.beginViewerDrag(x: start.x, y: start.y)) }
                }
                guard let start, let now = point(value.location) else { return }
                guard let live else { return perform(.moveViewerDrag(x: now.x, y: now.y)) }
                last = now
                // This view's model may not have the begin yet; the copy takes it too.
                var shown = model
                if shown.viewerDrag == nil { shown.beginViewerDrag(at: start) }
                shown.moveViewerDrag(to: now)
                live.project = shown
            }
            .onEnded { _ in
                if let last { perform(.moveViewerDrag(x: last.x, y: last.y)) }
                perform(.endViewerDrag)
                (dragging, start, last) = (false, nil, nil)
                live?.project = nil
            }
    }

    /// `location` in the artboard's points as composition pixels; nil before
    /// the artboard has a size or with no composition.
    private func point(_ location: CGPoint) -> HaloPoint? {
        model.compositionPoint(
            x: Double(location.x), y: Double(location.y),
            artboardWidth: Double(size.width), artboardHeight: Double(size.height))
    }
}
