// HaloViewerGestures.swift: the viewer's pointer input over the artboard
// (#207, LK-11). A clear, hit-testable view laid out on the artboard's fitted
// frame, the way HaloViewerCanvas lays out its layers, so the surround around
// it takes no hits and its points map through the Model's `compositionPoint`
// at the artboard's own size. A drag (minimum distance 0) hits and selects
// with `beginViewerDrag`. With a HaloLiveEdit the press writes nothing to the
// window: the hit, the selection and the moves show only in the live copy,
// and mouse-up sends the begin, the last move and the end together, since a
// write to the window's project lays out the whole window (seconds on huge's
// 2,000 layers) and swallowed the drag's samples. Its moves go to the
// window's HaloLiveEdit as the window's project with that move applied
// (`moveViewerDrag` on a copy, HaloLiveEdit.show), at most once per display
// refresh (HaloViewerPace, #4276; the latest move wins). Its first move also
// lifts the dragged layer (`viewerLift` into HaloLiveEdit.lift), so a sample
// only moves the lifted layer and redraws none (render contract rule 3); a
// layer that can't be lifted redraws the drawn layers per sample;
// the release sends the last `moveViewerDrag` and `endViewerDrag`, and the
// Model records one "Move". Hosted without a HaloLiveEdit, the begin goes at
// the press and each move is sent as it comes. A click focuses it, so Escape
// sends `cancelViewerDrag` and drops the live preview. It is hidden from accessibility: the artboard
// element (`halo.viewer`) around it names it. It reads its model and never
// assigns it. With the shape tool on (`haloShapeDrawing`, HS-3) a press
// draws through it instead. Under `-SuitePerfProbe` each move records a
// `viewer-drag` sample (HaloProbe), the first with `preview-before-mouse-up`.
import AppKit
import HaloModel
import SuiteKernel
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
    /// The press, in composition pixels; nil with no drag or after Escape.
    @State private var start: HaloPoint?
    /// The drag's moves, paced to one live write per refresh, and its last move.
    @State private var pace = HaloViewerPace()
    /// Whether this press draws a shape (the tool was on when it began).
    @State private var drawsShape = false
    @Environment(\.haloLiveEdit) private var live
    @Environment(\.haloShapeDrawing) private var shapes
    @Environment(\.haloViewerTakesActivationClicks) private var takesActivationClicks
    @Environment(\.suiteProbeRecorder) private var recorder

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
            .overlay { if let shapes { HaloShapeDraftView(drawing: shapes, artboard: artboard) } }
            .allowsWindowActivationEvents(takesActivationClicks)
            .aspectRatio(artboard, contentMode: .fit)
            .frame(maxWidth: artboard.width, maxHeight: artboard.height)
            .focusable()
            .focusEffectDisabled()
            .onExitCommand {
                if let shapes, drawsShape || shapes.isOn { return shapes.escape() }
                start = nil
                pace.cancel()
                live?.project = nil
                live?.lift = nil
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
                    drawsShape = shapes?.isOn == true
                    start = point(value.startLocation)
                    // With a live edit the press only previews; the window takes the begin at mouse-up.
                    if let start, !drawsShape, live == nil { perform(.beginViewerDrag(x: start.x, y: start.y)) }
                }
                if drawsShape, let shapes {
                    guard let start, let now = point(value.location) else { return }
                    return shapes.drag(model.shapeTool, from: start, to: now, modifiers: held)
                }
                guard let start, let now = point(value.location) else { return }
                let probe = HaloProbe(recorder)
                guard let live else {
                    perform(.moveViewerDrag(x: now.x, y: now.y))
                    return probe.sample(HaloProbe.viewerDrag)
                }
                if pace.isFresh {
                    var begun = live.current() ?? model
                    begun.beginViewerDrag(at: start)
                    // A press over empty space starts no drag; there is nothing to preview.
                    guard begun.viewerDrag != nil else { return self.start = nil }
                    live.lift = Self.lift(begun, at: start)
                }
                let first = pace.isFresh
                pace.move(to: now, probe: probe) { point in
                    live.show { shown in
                        // The window takes the begin at mouse-up; the copy takes it now.
                        if shown.viewerDrag == nil { shown.beginViewerDrag(at: start) }
                        shown.moveViewerDrag(to: point)
                    }
                }
                if first { probe.mark(HaloProbe.previewBeforeMouseUp, series: HaloProbe.viewerDrag) }
            }
            .onEnded { _ in
                if drawsShape {
                    (dragging, drawsShape, start) = (false, false, nil)
                    return shapes?.release() ?? ()
                }
                if live != nil, let start { perform(.beginViewerDrag(x: start.x, y: start.y)) }
                if let last = pace.end(probe: HaloProbe(recorder)) { perform(.moveViewerDrag(x: last.x, y: last.y)) }
                perform(.endViewerDrag)
                (dragging, start) = (false, nil)
                live?.project = nil
                live?.lift = nil
            }
    }

    /// The lift of a drag pressed at `start` on `project`; nil when the
    /// press hits nothing or the layer can't be lifted.
    nonisolated static func lift(_ project: HaloProject, at start: HaloPoint) -> HaloDrawLift? {
        var begun = project
        if begun.viewerDrag == nil { begun.beginViewerDrag(at: start) }
        return begun.viewerLift
    }

    /// The modifiers held now: Shift squares a shape, Option grows it from the centre.
    private var held: EditModifiers {
        let flags = NSEvent.modifierFlags
        return EditModifiers(rawValue: (flags.contains(.shift) ? 1 : 0) | (flags.contains(.option) ? 2 : 0))
    }

    /// `location` in the artboard's points as composition pixels; nil before
    /// the artboard has a size or with no composition.
    private func point(_ location: CGPoint) -> HaloPoint? {
        model.compositionPoint(
            x: Double(location.x), y: Double(location.y),
            artboardWidth: Double(size.width), artboardHeight: Double(size.height))
    }
}
