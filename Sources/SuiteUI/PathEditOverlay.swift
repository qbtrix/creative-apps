// PathEditOverlay.swift (pen-paths PN-2, PN-3): the Pen and point editor's
// overlay over a canvas, on the kernel's `PenDraft`, `PathInEdit` and
// `PathIntent`. It draws the path's and the draft's marks (selected anchors in
// the accent, the hovered one ringed), the rubber band from the draft's last
// anchor to the pointer, the handle a Pen drag pulls, the Direct Selection
// marquee and the close ring when a click would close the draft; it sets the
// pointer for what a click would do and reports every press, drag and key as
// intents the app runs. `PathGesture` holds the mapping, pure and testable:
// view points in, document-space intents out. The overlay keeps only its
// gesture, the pointer and focus; the app owns the draft, path and selection.
// PN-4 adds one hidden accessibility element per anchor and drawn handle.
// `pressesPassThrough()` keeps the marks and hover for a host whose own canvas
// gesture takes the presses. `holdsPressesUntilRelease()` runs a press's intents
// on a PathLiveDrag the overlay draws and hands them to the app once, at
// release, so an anchor or handle drag updates the host's window once.
import AppKit
import SuiteKernel
import SwiftUI

/// The path tool the overlay serves: the Pen adds anchors, Direct Selection picks and drags them.
public enum PenTool: String, CaseIterable, Sendable {
    case pen
    case directSelect

    public var title: String {
        switch self {
        case .pen: "Pen"
        case .directSelect: "Direct Selection"
        }
    }
}

/// The path being edited and the open Pen draft over the canvas, with their gestures.
public struct PathEditOverlay: View {
    private let context: PathContext
    private let onIntent: (PathIntent) -> Void
    /// false: marks and hover only (`pressesPassThrough()`, the stand-in init); presses, drags and keys reach the view under it.
    var takesPresses = true
    /// true: a press's intents go to `live` and reach `onIntent` together at release (`holdsPressesUntilRelease()`).
    var holdsPresses = false
    @State private var live: PathLiveDrag?
    @State private var tracker = PathGesture()
    @State private var pointer: CGPoint?
    @State private var hovered: PathHit?
    @State private var indexed: (path: PathInEdit, index: AnchorIndex)?
    @FocusState private var hasFocus: Bool

    /// `draft` is the open Pen path (document space) and `path` the path whose
    /// points are edited; `selection` its selected anchors; `zoom` in points
    /// per pixel. `onIntent` gets each gesture and key as an intent, its points
    /// and deltas in document space.
    public init(draft: PenDraft?, path: PathInEdit?, selection: Selection<AnchorRef>, tool: PenTool, zoom: Double,
                onIntent: @escaping (PathIntent) -> Void) {
        context = PathContext(draft: draft, path: path, selection: selection, tool: tool, zoom: zoom)
        self.onIntent = onIntent
    }

    /// The overlay with the pointer resting at `pointer` (view points), as a hover leaves it: the rubber band
    /// and close ring a snapshot shows without a mouse.
    init(draft: PenDraft?, path: PathInEdit?, selection: Selection<AnchorRef>, tool: PenTool, zoom: Double, pointer: CGPoint?,
         onIntent: @escaping (PathIntent) -> Void) {
        self.init(draft: draft, path: path, selection: selection, tool: tool, zoom: zoom, onIntent: onIntent)
        _pointer = State(initialValue: pointer)
    }

    public var body: some View {
        let hint = pointer.map { PathGesture.hint(at: $0, hit: hovered, in: context) }
        let shown = live.map { ($0.pathInEdit, $0.anchorSelection) } ?? (context.path, context.selection)
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(.rect)
            if let path = shown.0 {
                PathEditMarks(path: path, selection: shown.1, hovered: context.tool == .directSelect ? hovered : nil,
                              zoom: context.zoom).equatable()
            }
            if let draft = context.draft {
                PathMarks(contours: [draft.contour], toView: .identity, selected: [], hovered: nil, zoom: context.zoom)
            }
            guides(hint: hint)
            if let path = context.path {
                PathAnchorProbes(path: path, selection: context.selection, zoom: context.zoom).equatable()
            }
        }
        .contentShape(.rect)
        .onContinuousHover { phase in
            if case .active(let p) = phase { (pointer, hovered) = (p, hitTest(p)) } else { (pointer, hovered) = (nil, nil) }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                let held = KeyModifiers(flags: NSEvent.modifierFlags)
                if tracker.pressed == nil {
                    hasFocus = true
                    send(tracker.press(at: value.startLocation, hit: hitTest(value.startLocation), modifiers: held,
                                       token: CoalesceKey.token(nil), in: context))
                }
                pointer = value.location
                send(tracker.drag(to: value.location, modifiers: held))
            }
            .onEnded { value in send(tracker.release(at: value.location, modifiers: KeyModifiers(flags: NSEvent.modifierFlags))) },
            isEnabled: takesPresses)
        .pointerStyle(hint.map { look($0) })
        .focusable(takesPresses)
        .focused($hasFocus)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            guard let key = PathKey(press.key) else { return .ignored }
            let intents = PathGesture.key(key, modifiers: press.modifiers.contains(.shift) ? .shift : [], in: context)
            send(intents)
            return intents.isEmpty ? .ignored : .handled
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Path editor")
        .accessibilityValue(context.draft.map { "Drawing, \($0.contour.anchors.count) points" }
            ?? "\(context.selection.ordered.count) points selected")
        .suiteControl(id: "suite.path.overlay", enabled: true, reason: nil)
    }

    /// The overlay as marks and hover only, for a host whose own canvas gesture routes every press (Flare's stage):
    /// its drag gesture, focus and keys are off, so `onIntent` gets nothing, but it stays hit-tested, so hover still
    /// draws the rubber band, close ring and hovered ring and sets the pointer. Don't wrap it in
    /// `.allowsHitTesting(false)`: that drops the hover too.
    public func pressesPassThrough() -> Self {
        var overlay = self
        overlay.takesPresses = false
        return overlay
    }

    /// The overlay holding each press's intents until release: the samples move a copy only this view draws, and the
    /// host gets the press's intents in order at mouse-up, as one batch, its drag's edits under one token.
    public func holdsPressesUntilRelease() -> Self {
        var overlay = self
        overlay.holdsPresses = true
        return overlay
    }

    /// The rubber band, the handle a Pen drag pulls, the marquee and the close ring.
    @ViewBuilder private func guides(hint: PathCursorHint?) -> some View {
        let s = context.scale
        let view = { (p: Point) in CGPoint(x: p.x * s, y: p.y * s) }
        if tracker.pressed == nil, context.tool == .pen, let pointer, let end = context.draft?.contour.anchors.last {
            Path { band in
                band.move(to: view(end.point))
                if let out = end.handleOut { band.addQuadCurve(to: pointer, control: view(out)) } else { band.addLine(to: pointer) }
            }
            .stroke(SuiteColor.accent, lineWidth: 1)
            .accessibilityHidden(true)
        }
        if let pull = tracker.penHandle {
            let mirror = Point(x: 2 * pull.anchor.x - pull.handle.x, y: 2 * pull.anchor.y - pull.handle.y)
            Path { line in
                line.move(to: view(mirror))
                line.addLine(to: view(pull.handle))
            }
            .stroke(SuiteColor.accent, lineWidth: 1)
            .accessibilityHidden(true)
        }
        if let rect = tracker.marquee {
            Path(CGRect(x: rect.minX * s, y: rect.minY * s, width: (rect.maxX - rect.minX) * s, height: (rect.maxY - rect.minY) * s))
                .stroke(SuiteColor.accent, lineWidth: 1)
                .accessibilityHidden(true)
        }
        if hint == .close, let first = context.draft?.contour.anchors.first {
            PathMarks.ring(CGPoint(x: first.point.x, y: first.point.y), zoom: context.zoom)
                .stroke(SuiteColor.accent, lineWidth: 2)
                .accessibilityElement()
                .accessibilityLabel("Close path")
                .accessibilityIdentifier("suite.path.close-ring")
        }
    }

    /// The pointer's look for what a click would do.
    private func look(_ hint: PathCursorHint) -> PointerStyle {
        switch hint {
        case .penAdd, .addPoint, .removePoint: .rectSelection
        case .moveAnchor, .moveHandle: tracker.pressed == nil ? .grabIdle : .grabActive
        case .close, .marquee: .default
        }
    }

    /// The anchor, handle or segment of the path under `location`, within half `SuiteSize.anchorHit` on screen.
    private func hitTest(_ location: CGPoint) -> PathHit? {
        guard let path = context.path else { return nil }
        if indexed?.path != path { indexed = (path, AnchorIndex(path.path, toDocument: path.toDocument)) }
        let reach = SuiteSize.anchorHit / 2 / context.scale
        return indexed?.index.hit(context.document(location), reach: reach, selected: context.selection)
    }

    /// Hands `intents` to the host, or, while a held press lasts, runs them on its copy; the release hands over all.
    private func send(_ intents: [PathIntent]) {
        guard holdsPresses else { return intents.forEach(onIntent) }
        if tracker.pressed != nil {
            var copy = live ?? PathLiveDrag(draft: context.draft, path: context.path, selection: context.selection)
            intents.forEach { copy.run($0) }
            live = copy
        } else {
            let held = (live?.held ?? []) + intents
            live = nil
            held.forEach(onIntent)
        }
    }
}

/// The edited path's marks, rebuilt only when the path, selection, hovered mark or zoom changes: a drag sample
/// that moves only the marquee or the pointer re-runs the overlay, not these (RenderBudgetPenPathsTests).
struct PathEditMarks: View, Equatable {
    let path: PathInEdit, selection: Selection<AnchorRef>, hovered: PathHit?, zoom: Double

    var body: some View {
        PathMarks(contours: path.path.contours, toView: path.toDocument, selected: selection.set, hovered: hovered, zoom: zoom)
    }
}

/// One hidden accessibility element over an anchor or handle: its id, what VoiceOver reads, its box in document points.
struct PathAnchorProbe: Hashable, Sendable {
    let id: String, label: String, rect: CGRect
}

/// The path's anchors and drawn handles as hidden accessibility elements, for VoiceOver and the journeys:
/// `suite.path.anchor-<c>-<i>` reads "Anchor 2 of 4, smooth", `suite.path.handle-<c>-<i>-out` is its out handle.
/// Only the first `limit` anchors get one, so a 5,000-anchor path stays cheap. It draws nothing and takes no hits.
struct PathAnchorProbes: View, Equatable {
    static let limit = 200
    let path: PathInEdit, selection: Selection<AnchorRef>, zoom: Double

    nonisolated static func == (a: Self, b: Self) -> Bool {
        a.path == b.path && a.selection == b.selection && a.zoom == b.zoom
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.probes(path, selection: selection, zoom: zoom), id: \.id) { probe in
                ProbeElement(probe.id, label: probe.label, rect: probe.rect, zoom: zoom)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Path anchors")
        .accessibilityValue("\(path.path.contours.reduce(0) { $0 + $1.anchors.count }) anchors, \(selection.ordered.count) selected")
        .accessibilityIdentifier("suite.path.anchors")
    }

    /// Each anchor's probe, then its handles' when it is smooth or selected (the handles the marks draw): a
    /// `SuiteSize.anchorHit` box on screen around the point.
    nonisolated static func probes(_ path: PathInEdit, selection: Selection<AnchorRef>, zoom: Double) -> [PathAnchorProbe] {
        let side = SuiteSize.anchorHit / PathMarks.scale(zoom)
        func box(_ p: Point) -> CGRect {
            let v = path.toDocument.apply(p)
            return CGRect(x: v.x - side / 2, y: v.y - side / 2, width: side, height: side)
        }
        var probes: [PathAnchorProbe] = [], named = 0
        for (c, contour) in path.path.contours.enumerated() {
            for (i, anchor) in contour.anchors.enumerated() where named < limit {
                named += 1
                let picked = selection.contains(AnchorRef(contour: c, index: i))
                let kind = anchor.kind == .corner ? "corner" : "smooth"
                probes.append(PathAnchorProbe(id: "suite.path.anchor-\(c)-\(i)", label: "Anchor \(i + 1) of \(contour.anchors.count), "
                                              + kind + (picked ? ", selected" : ""), rect: box(anchor.point)))
                guard anchor.kind != .corner || picked else { continue }
                for (end, handle) in [("in", anchor.handleIn), ("out", anchor.handleOut)] {
                    guard let handle else { continue }
                    probes.append(PathAnchorProbe(id: "suite.path.handle-\(c)-\(i)-\(end)",
                                                  label: (end == "in" ? "In" : "Out") + " handle of anchor \(i + 1)", rect: box(handle)))
                }
            }
        }
        return probes
    }
}
