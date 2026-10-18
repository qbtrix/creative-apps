// CanvasMarks+Vector.swift: a selection box an editor can drag (canvas-marks
// CM-4, part of #273). It adopts editor-kernel's SelectionHandles (EK-5) for
// the drawing and adds the gesture: the eight handles and the four rotate
// zones hit where SuiteHandleGeometry says (12 pt squares and 16 pt zones in
// view points at any zoom; the knob EK-5 draws above the top edge rotates
// too), a handle drag resizes the box (⇧ keeps its aspect), a zone or knob
// drag turns it (⇧ snaps to 15°), and the drag ends once on mouse-up
// through an EditRun, so the host makes it one undo step. The box's edges
// sit on the device pixel grid, so its 1 pt outline is two crisp device
// pixels at scale 2. SwiftUI has no rotate pointer (PointerStyle), so a
// rotate zone shows the crosshair, `rectSelection`. Under a probe host each
// drag sample reports on the `handle-drag` series (HandleDragProbe).
import AppKit
import SuiteKernel
import SwiftUI

/// What one drag sample does to the box.
public enum SelectionHandleEdit: Equatable, Sendable {
    /// The box after the drag so far, in document pixels.
    case resize(CGRect)
    /// Degrees turned about the box's centre so far, clockwise positive.
    case rotate(Double)
}

/// One handle drag, from the press to the release: which handle the press
/// took, and the run that makes the drag one end. Pure, so tests drive it.
public struct SelectionHandleDrag: Equatable, Sendable {
    private enum Grab: Equatable, Sendable { case none, missed, handle(HandleKind), knob }

    private var grab = Grab.none
    private var startRect = CGRect.zero
    private var run = EditRun()

    /// Ends reported so far: one per drag that changed the box.
    public var ends: Int { run.ends }

    public init() {}

    /// Each handle's and rotate zone's hit rect in view points around `rect`
    /// (document pixels) at `zoom`: SuiteHandleGeometry's 12 pt squares and
    /// 16 pt zones, the same size at every zoom.
    public nonisolated static func hitRects(rect: CGRect, zoom: Double) -> [HandleKind: CGRect] {
        SuiteHandleGeometry().handles(around: plane(viewRect(rect, zoom: zoom)), hitSize: hitSize, rotateZone: zoneSize)
            .mapValues { CGRect(x: $0.minX, y: $0.minY, width: $0.extent.width, height: $0.extent.height) }
    }

    /// `rect` with its edges moved to the nearest device pixel at `zoom` and
    /// `scale` (device pixels per point), each side an even number of device
    /// pixels so the edge handles' centres land on the grid too: the outline
    /// and every handle sit on the pixel grid. A non-finite rect or a
    /// non-positive scale comes back as it was.
    public nonisolated static func aligned(_ rect: CGRect, zoom: Double, scale: Double) -> CGRect {
        let s = MotionPathMarks.scale(zoom)
        let edges = [rect.minX, rect.minY, rect.maxX, rect.maxY].map { (Double($0) * s * scale).rounded() }
        guard scale > 0, edges.allSatisfy(\.isFinite) else { return rect }
        let even = { (low: Double, high: Double) in (high - low).truncatingRemainder(dividingBy: 2) == 0 ? high : high + 1 }
        let r = [edges[0], edges[1], even(edges[0], edges[2]), even(edges[1], edges[3])].map { $0 / scale / s }
        return CGRect(x: r[0], y: r[1], width: r[2] - r[0], height: r[3] - r[1])
    }

    /// A drag sample from `start` to `point` (view points) over `rect`
    /// (document pixels) at `zoom`. The first sample takes the handle under
    /// `start` and keeps `rect` as the drag's start, so the host's updates to
    /// `rect` mid-drag never compound; a press on no handle edits nothing for
    /// the whole drag. `knob` is the rotate knob's mark (view points), whose
    /// 12 pt square rotates. Nil when nothing is grabbed.
    public mutating func changed(rect: CGRect, zoom: Double, from start: CGPoint, to point: CGPoint,
                                 shift: Bool, knob: CGRect? = nil) -> SelectionHandleEdit? {
        let view = Self.viewRect(grab == .none ? rect : startRect, zoom: zoom)
        if grab == .none {
            startRect = rect
            if let knob, knob.insetBy(dx: (knob.width - SuiteSize.selectionHandleHit) / 2,
                                       dy: (knob.height - SuiteSize.selectionHandleHit) / 2).contains(start) {
                grab = .knob
            } else {
                let kind = SuiteHandleGeometry().hit(Self.plane(start), around: Self.plane(view),
                                                     hitSize: Self.hitSize, rotateZone: Self.zoneSize)
                grab = kind.map(Grab.handle) ?? .missed
            }
        }
        let geometry = SuiteHandleGeometry()
        let edit: SelectionHandleEdit
        switch grab {
        case .none, .missed: return nil
        case .knob, .handle(.rotateTopLeft), .handle(.rotateTopRight), .handle(.rotateBottomRight),
             .handle(.rotateBottomLeft):
            edit = .rotate(geometry.rotation(from: Self.plane(start), to: Self.plane(point),
                                             center: Self.plane(view).mid, snap: shift))
        case let .handle(kind):
            let s = MotionPathMarks.scale(zoom)
            let delta = PlanePoint(x: Double(point.x - start.x) / s, y: Double(point.y - start.y) / s)
            let r = geometry.resized(Self.plane(startRect), handle: kind, by: delta, keepAspect: shift)
            edit = .resize(CGRect(x: r.minX, y: r.minY, width: r.extent.width, height: r.extent.height))
        }
        _ = run.change()
        return edit
    }

    /// The release: true exactly once per drag that edited, never for a press
    /// that missed. The next press grabs afresh.
    public mutating func ended() -> Bool {
        grab = .none
        return run.end()
    }

    private nonisolated static let hitSize = Double(SuiteSize.selectionHandleHit)
    private nonisolated static let zoneSize = Double(SuiteSize.rotateZone)

    private nonisolated static func viewRect(_ rect: CGRect, zoom: Double) -> CGRect {
        let s = MotionPathMarks.scale(zoom)
        return CGRect(x: Double(rect.minX) * s, y: Double(rect.minY) * s, width: Double(rect.width) * s, height: Double(rect.height) * s)
    }

    private nonisolated static func plane(_ r: CGRect) -> PlaneRect {
        PlaneRect(x: Double(r.minX), y: Double(r.minY), width: Double(r.width), height: Double(r.height))
    }

    private nonisolated static func plane(_ p: CGPoint) -> PlanePoint { PlanePoint(x: Double(p.x), y: Double(p.y)) }
}

/// A selection box with handles to drag, in a CanvasViewport's overlay: the
/// packet's `SelectionHandles(rect:zoom:onResize:onRotate:onEnd:)`, named
/// apart because EK-5's drawing took `SelectionHandles`.
public struct SelectionHandlesEditor: View {
    private let rect: CGRect
    private let zoom: Double
    private let onResize: @MainActor (CGRect) -> Void
    private let onRotate: @MainActor (Double) -> Void
    private let onEnd: @MainActor () -> Void
    @State private var drag = SelectionHandleDrag()
    @State private var hovered: EditorHandle?
    @Environment(\.displayScale) private var scale
    @Environment(\.handleDragProbe) private var probe

    /// `rect` in document pixels; `zoom` in points per pixel. A drag sends
    /// the box so far to `onResize` (document pixels) or the turn so far to
    /// `onRotate` (degrees), then `onEnd` once on mouse-up.
    public init(rect: CGRect, zoom: Double, onResize: @escaping @MainActor (CGRect) -> Void,
                onRotate: @escaping @MainActor (Double) -> Void, onEnd: @escaping @MainActor () -> Void) {
        self.rect = rect
        self.zoom = zoom
        self.onResize = onResize
        self.onRotate = onRotate
        self.onEnd = onEnd
    }

    public var body: some View {
        let box = SelectionHandleDrag.aligned(rect, zoom: zoom, scale: Double(scale))
        let kernelBox = Rect(minX: Double(box.minX), minY: Double(box.minY), maxX: Double(box.maxX), maxY: Double(box.maxY))
        let handles = BoxMath.handles(of: kernelBox, size: Double(SuiteSize.selectionHandle) / MotionPathMarks.scale(zoom))
        let knob = SelectionHandles.marks(handles: handles, zoom: zoom).first { $0.handle == .rotate }?.frame
        ZStack(alignment: .topLeading) {
            ForEach(HandleKind.allCases, id: \.self) { kind in
                if let hit = SelectionHandleDrag.hitRects(rect: box, zoom: zoom)[kind] {
                    Color.clear
                        .frame(width: hit.width, height: hit.height)
                        .contentShape(Rectangle())
                        .pointerStyle(kind.rawValue.hasPrefix("rotate") ? .rectSelection : .default)
                        .position(x: hit.midX, y: hit.midY)
                }
            }
            SelectionHandles(box: kernelBox, handles: handles, zoom: zoom, hovered: hovered) { hovered = $0 }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .local)
                .onChanged { value in
                    let shift = NSEvent.modifierFlags.contains(.shift)
                    let eventTime = NSApp.currentEvent?.timestamp ?? ProcessInfo.processInfo.systemUptime
                    switch drag.changed(rect: box, zoom: zoom, from: value.startLocation, to: value.location,
                                        shift: shift, knob: knob) {
                    case let .resize(next)?: onResize(next)
                    case let .rotate(degrees)?: onRotate(degrees)
                    case nil: return
                    }
                    report(eventTime)
                }
                .onEnded { _ in if drag.ended() { onEnd() } })
    }

    /// A drag sample, shown by the next main-actor turn after the change.
    private func report(_ eventTime: Double) {
        guard let probe else { return }
        Task { @MainActor in
            probe.record(ProbeSample(series: HandleDragProbe.series, eventTime: eventTime,
                                     shownAt: ProcessInfo.processInfo.systemUptime))
        }
    }
}

/// Where a SelectionHandlesEditor reports each drag sample, on series
/// `handle-drag`; a probe host sets it, and nil records nothing.
struct HandleDragProbe: Sendable {
    static let series = "handle-drag"
    let record: @MainActor @Sendable (ProbeSample) -> Void
}

extension EnvironmentValues {
    /// Where a SelectionHandlesEditor reports its probe samples; nil records nothing.
    var handleDragProbe: HandleDragProbe? {
        get { self[HandleDragProbeKey.self] }
        set { self[HandleDragProbeKey.self] = newValue }
    }
}

private struct HandleDragProbeKey: EnvironmentKey {
    static let defaultValue: HandleDragProbe? = nil
}
