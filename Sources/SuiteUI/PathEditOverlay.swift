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
    /// False for the stand-in init in PathEditOverlay+StandIn.swift: marks only, no gesture.
    var interactive = true
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

    public var body: some View {
        let hint = pointer.map { PathGesture.hint(at: $0, hit: hovered, in: context) }
        ZStack(alignment: .topLeading) {
            Color.clear.contentShape(.rect)
            if let path = context.path {
                PathMarks(contours: path.path.contours, toView: path.toDocument, selected: context.selection.set,
                          hovered: context.tool == .directSelect ? hovered : nil, zoom: context.zoom)
            }
            if let draft = context.draft {
                PathMarks(contours: [draft.contour], toView: .identity, selected: [], hovered: nil, zoom: context.zoom)
            }
            guides(hint: hint)
        }
        .contentShape(.rect)
        .allowsHitTesting(interactive)
        .onContinuousHover { phase in
            if case .active(let p) = phase { (pointer, hovered) = (p, hitTest(p)) } else { (pointer, hovered) = (nil, nil) }
        }
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { value in
                let held = KeyModifiers(flags: NSEvent.modifierFlags)
                if tracker.pressed == nil {
                    hasFocus = true
                    send(tracker.press(at: value.startLocation, hit: hitTest(value.startLocation), modifiers: held,
                                       token: UUID().uuidString, in: context))
                }
                pointer = value.location
                send(tracker.drag(to: value.location, modifiers: held))
            }
            .onEnded { value in send(tracker.release(at: value.location, modifiers: KeyModifiers(flags: NSEvent.modifierFlags))) })
        .pointerStyle(hint.map { look($0) })
        .focusable()
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

    private func send(_ intents: [PathIntent]) {
        for intent in intents { onIntent(intent) }
    }
}
