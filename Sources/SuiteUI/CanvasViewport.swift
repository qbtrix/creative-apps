// CanvasViewport.swift: the canvas of an editor shell. The document (an
// image, an artboard) sits on a checkerboard at `zoom` points per document
// pixel, centred while it fits and scrollable with a margin once it doesn't,
// with rulers along the top and left that follow the zoom and the scroll
// (Ruler); their corner (RulerCorner) names the document's unit, "px" unless
// the app passes `rulerUnit` ("pt" for Design; the older `unit` label, when
// given, wins). Pointer drags arrive in document pixels: `onDrag(from:to:)` once
// per move with the previous and current point (a click is a drag that
// doesn't move), then `onDragEnd`. Pinch zooms through `onZoom` about the
// pointer: the viewport scrolls so the document point under it stays put
// (CanvasLayout's anchoredOffset over ZoomMath.anchoredOrigin), once the
// content has taken its new size. Key presses
// reach `onKey` while the canvas has focus, which a drag on it gives it.
// While it has focus the canvas also pans without a scroll wheel: a drag that
// starts with Space held scrolls it with the pointer (the grab pointer) and
// never reaches `onDrag` or `onDragEnd`, and Space never reaches `onKey`; an
// arrow key `onKey` ignores scrolls a tenth of the viewport, Shift a whole
// one. Whether a drag pans is decided when it starts, so a tool drag always
// gets its `onDragEnd`. The host owns the zoom (the top bar and status bar
// show it) and learns the viewport's size from `onSize` to work out a fit.
// With `onZoomLevel` (or the older `onZoom`, which takes the level as a
// scale), the viewport also zooms itself through SuiteKernel's zoom model,
// clamped to 10% to 3200%: pinch, landing on 100% when it passes near it, and
// Command-plus, Command-minus, Command-0 (fit) and Command-1 (100%) while it
// has focus. A host that takes `.fit` keeps the picture fitted as the window
// resizes (ZoomMath.scale); `onZoom` gets the fit as a scale, from the
// environment's `canvasFitScale` (EditorDetail's palette-clear fit) when set.
// `showsRulers: false` drops the rulers and their corner; the canvas keeps
// an empty band where they were (CanvasLayout's `inset`), so the artboard
// doesn't jump. A drag that starts on a ruler goes to `onRulerDrag`, never
// `onDrag`: a RulerDrag per move and one on release, carrying the ruler's axis
// (.horizontal for the top one), the document coordinate across it and, on
// release, whether the pointer is back over the ruler (the host removes the
// guide then). `checkerboard: false` puts the document on the plain artboard color
// instead of the checkerboard. `onPointer`
// reports the document point under the pointer, nil once it leaves the artboard.
// CanvasLayout is the placement and pan math, plain and tested on its own;
// every pan is clamped to its scrollable area, and it draws no scroll bars. The content is clipped to the
// artboard; the overlay (selection outlines and handles, inline editors) is
// laid out on the artboard but not clipped, so marks on a shape that crosses
// the document's edge still show. Content, not chrome: flat, no glass. The
// artboard's container carries the accessibility element `suite.canvas`;
// XCUITest reads that container, which has no children of its own, at the
// scrollable area's frame (the viewport, or the artboard plus its margin), and
// the app journeys drag on it by normalized offsets of that area (#566). The
// artboard's own rectangle at the current zoom is the leaf element
// `suite.canvas.artboard`, for a journey that measures the document. The
// container registers as the enabled control `suite.canvas` (`.suiteControl`),
// and under a probe host each tool-drag or Space-pan move reports a sample of
// series `canvas-drag` (CanvasProbe, SP2).
import enum SuiteKernel.ZoomKey
import enum SuiteKernel.ZoomLevel
import SwiftUI

/// Where the artboard sits in the scrollable canvas, in points.
public struct CanvasLayout: Equatable, Sendable {
    /// Points per document pixel; a zoom that isn't a positive finite number is 1.
    public let scale: Double
    /// The document drawn at `scale`.
    public let artboard: CGSize
    /// The scrollable area: the viewport, or the artboard plus a margin on
    /// every side once that is larger.
    public let content: CGSize
    /// The artboard's top-left corner in the scrollable area.
    public let origin: CGPoint
    /// The visible part of the scrollable area.
    public let viewport: CGSize
    /// The empty band along the leading and top edges where hidden rulers were; 0 with them shown.
    public let inset: CGFloat

    /// Non-positive document sides count as one pixel, as CanvasSurface does. With an `inset`, the artboard
    /// is placed as in a viewport that much smaller, then moved past the band, so it keeps its place on screen.
    public init(document: CGSize, zoom: Double, viewport: CGSize, margin: CGFloat = SuiteSpacing.xxl, inset: CGFloat = 0) {
        let scale = zoom.isFinite && zoom > 0 ? zoom : 1
        let inset = max(inset, 0)
        let artboard = CGSize(
            width: max(document.width, 1) * scale, height: max(document.height, 1) * scale)
        let content = CGSize(
            width: max(viewport.width - inset, artboard.width + 2 * margin),
            height: max(viewport.height - inset, artboard.height + 2 * margin))
        self.scale = scale
        self.artboard = artboard
        self.content = CGSize(width: content.width + inset, height: content.height + inset)
        self.viewport = viewport
        self.inset = inset
        origin = CGPoint(x: (content.width - artboard.width) / 2 + inset, y: (content.height - artboard.height) / 2 + inset)
    }

    /// The drag out of the `axis` ruler at `point`, in viewport points (the top ruler lies above y 0, the left
    /// one left of x 0) with the canvas scrolled to `scrolled`: the document coordinate across the ruler (y for
    /// the top one), and whether the pointer is over that ruler again.
    public func rulerDrag(_ axis: Axis, _ phase: RulerDrag.Phase, at point: CGPoint, scrolled: CGPoint) -> RulerDrag {
        let document = documentPoint(CGPoint(x: point.x + scrolled.x, y: point.y + scrolled.y))
        let horizontal = axis == .horizontal
        return RulerDrag(
            axis: axis, phase: phase, position: horizontal ? document.y : document.x,
            isOverRuler: horizontal ? point.y < 0 : point.x < 0)
    }

    /// The document point under `point` in the scrollable area.
    public func documentPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - origin.x) / scale, y: (point.y - origin.y) / scale)
    }

    /// The document point under `point`, or nil when `point` is off the artboard.
    public func artboardPoint(_ point: CGPoint) -> CGPoint? {
        let document = documentPoint(point)
        let size = CGSize(width: artboard.width / scale, height: artboard.height / scale)
        guard document.x >= 0, document.y >= 0, document.x < size.width, document.y < size.height else { return nil }
        return document
    }

    /// `offset` kept inside the scrollable area, so the viewport never shows past its edges.
    public func clamped(_ offset: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(offset.x, 0), max(content.width - viewport.width, 0)),
            y: min(max(offset.y, 0), max(content.height - viewport.height, 0)))
    }

    /// The scroll offset once a pan that began at `start` has moved the pointer by
    /// `translation`: the content follows the pointer.
    public func panned(from start: CGPoint, by translation: CGSize) -> CGPoint {
        clamped(CGPoint(x: start.x - translation.width, y: start.y - translation.height))
    }

    /// The scroll offset, clamped to `next`'s scrollable area, that keeps the document point under
    /// `pointer` (in viewport points) under it when this layout, scrolled to `scrolled`, zooms to `next`.
    public func anchoredOffset(to next: CanvasLayout, pointer: CGPoint, scrolled: CGPoint) -> CGPoint {
        let origin = ZoomMath.anchoredOrigin(
            pointer: pointer, origin: CGPoint(x: self.origin.x - scrolled.x, y: self.origin.y - scrolled.y),
            from: scale, to: next.scale)
        return next.clamped(CGPoint(x: next.origin.x - origin.x, y: next.origin.y - origin.y))
    }

    /// The scroll offset after `key`: an arrow scrolls a tenth of the viewport its way,
    /// a whole viewport with `page` (Shift). Nil for any other key.
    public func panned(from offset: CGPoint, key: KeyEquivalent, page: Bool) -> CGPoint? {
        let step = page ? viewport : CGSize(width: viewport.width / 10, height: viewport.height / 10)
        let moved: CGPoint
        switch key {
        case .leftArrow: moved = CGPoint(x: offset.x - step.width, y: offset.y)
        case .rightArrow: moved = CGPoint(x: offset.x + step.width, y: offset.y)
        case .upArrow: moved = CGPoint(x: offset.x, y: offset.y - step.height)
        case .downArrow: moved = CGPoint(x: offset.x, y: offset.y + step.height)
        default: return nil
        }
        return clamped(moved)
    }
}

/// A guide dragged out of a ruler: which ruler, the drag's phase, the document coordinate across the
/// ruler, and whether the pointer is back over the ruler.
public struct RulerDrag: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case changed, ended }
    public let axis: Axis, phase: Phase, position: Double, isOverRuler: Bool
    public init(axis: Axis, phase: Phase, position: Double, isOverRuler: Bool) {
        (self.axis, self.phase, self.position, self.isOverRuler) = (axis, phase, position, isOverRuler)
    }
}

public struct CanvasViewport<Content: View, Overlay: View>: View {
    private let documentSize: CGSize
    private let zoom: Double
    private let pointer: PointerStyle?
    private let checkerboard: Bool
    private let showsRulers: Bool
    /// The unit the ruler corner names: "px" unless the app's document is in another one.
    public let rulerUnit: String
    /// The ruler corner's unit under its older name.
    var unit: String { rulerUnit }
    private let onSize: @MainActor (CGSize) -> Void
    private let onZoom: (@MainActor (Double) -> Void)?
    private let onZoomLevel: (@MainActor (ZoomLevel) -> Void)?
    private let onDrag: (@MainActor (CGPoint, CGPoint) -> Void)?
    private let onDragEnd: (@MainActor () -> Void)?
    private let onKey: (@MainActor (KeyPress) -> KeyPress.Result)?
    private let onPointer: (@MainActor (CGPoint?) -> Void)?
    private let onRulerDrag: (@MainActor (RulerDrag) -> Void)?
    private let content: Content
    private let overlay: Overlay
    @State private var scrolled: CGPoint = .zero
    @State private var last: CGPoint?
    /// Where the pinch under way began: the zoom, layout and scroll then, and the pointer in the viewport.
    @State private var pinchStart: (zoom: Double, layout: CanvasLayout, scrolled: CGPoint, pointer: CGPoint)?
    /// The offset a pinch scrolls to once the content takes its new size.
    @State private var pendingScroll: CGPoint?
    @State private var position = ScrollPosition()
    @State private var spaceHeld = false
    /// The scroll offset where the pan under way began; nil while no pan is.
    @State private var panStart: CGPoint?
    @FocusState private var isFocused: Bool
    @Environment(\.canvasFitScale) private var fitScale
    @Environment(\.canvasProbe) private var probe

    /// `documentSize` in pixels; `content` and `overlay` are laid out at the
    /// artboard's size (the document at `zoom`), overlay on top. Only the
    /// content is clipped to the artboard. The checkerboard shows behind it
    /// unless `checkerboard` is false. The ruler corner names `rulerUnit`, or
    /// `unit` when an app still passes that label; `showsRulers: false` hides them.
    public init(
        documentSize: CGSize, zoom: Double, pointer: PointerStyle? = nil, checkerboard: Bool = true,
        showsRulers: Bool = true, rulerUnit: String = "px", unit: String? = nil,
        onSize: @escaping @MainActor (CGSize) -> Void = { _ in },
        onZoom: (@MainActor (Double) -> Void)? = nil,
        onZoomLevel: (@MainActor (ZoomLevel) -> Void)? = nil,
        onDrag: (@MainActor (CGPoint, CGPoint) -> Void)? = nil,
        onDragEnd: (@MainActor () -> Void)? = nil,
        onKey: (@MainActor (KeyPress) -> KeyPress.Result)? = nil,
        onPointer: (@MainActor (CGPoint?) -> Void)? = nil,
        onRulerDrag: (@MainActor (RulerDrag) -> Void)? = nil,
        @ViewBuilder content: () -> Content, @ViewBuilder overlay: () -> Overlay
    ) {
        self.documentSize = documentSize
        self.zoom = zoom
        self.pointer = pointer
        self.checkerboard = checkerboard
        self.showsRulers = showsRulers
        self.rulerUnit = unit ?? rulerUnit
        self.onSize = onSize
        self.onZoom = onZoom
        self.onZoomLevel = onZoomLevel
        self.onDrag = onDrag
        self.onDragEnd = onDragEnd
        self.onKey = onKey
        self.onPointer = onPointer
        self.onRulerDrag = onRulerDrag
        self.content = content()
        self.overlay = overlay()
    }

    public var body: some View {
        GeometryReader { geometry in
            // Hidden rulers leave their band to the canvas, so the size the host fits to stays the same.
            let band = showsRulers ? SuiteSize.ruler : 0
            let viewport = CGSize(
                width: max(geometry.size.width - SuiteSize.ruler, 0),
                height: max(geometry.size.height - SuiteSize.ruler, 0))
            let layout = CanvasLayout(
                document: documentSize, zoom: zoom,
                viewport: CGSize(width: viewport.width + SuiteSize.ruler - band, height: viewport.height + SuiteSize.ruler - band),
                inset: SuiteSize.ruler - band)
            VStack(spacing: 0) {
                if showsRulers {
                    HStack(spacing: 0) {
                        RulerCorner(unit: rulerUnit)
                        ruler(.horizontal, layout)
                    }
                }
                HStack(spacing: 0) {
                    if showsRulers { ruler(.vertical, layout) }
                    scroller(layout)
                }
            }
            .coordinateSpace(.named(Self.space))
            .onAppear { onSize(viewport) }
            .onChange(of: viewport) { _, size in onSize(size) }
        }
    }

    /// The viewport's frame, the corner at its origin, in which a ruler drag reads the pointer.
    nonisolated private static var space: String { "suite.canvas.frame" }

    /// A ruler, taking guide drags when the host does.
    private func ruler(_ axis: Axis, _ layout: CanvasLayout) -> some View {
        let origin = axis == .horizontal ? layout.origin.x - scrolled.x : layout.origin.y - scrolled.y
        return Ruler(axis: axis, origin: origin, scale: layout.scale)
            .gesture(rulerDrag(axis, layout), isEnabled: onRulerDrag != nil)
    }

    /// A drag from a ruler: each move and the release, in the viewport's points (the rulers' band is negative).
    private func rulerDrag(_ axis: Axis, _ layout: CanvasLayout) -> some Gesture {
        let report = { (phase: RulerDrag.Phase, location: CGPoint) in
            let point = CGPoint(x: location.x - SuiteSize.ruler, y: location.y - SuiteSize.ruler)
            onRulerDrag?(layout.rulerDrag(axis, phase, at: point, scrolled: scrolled))
        }
        return DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
            .onChanged { report(.changed, $0.location) }
            .onEnded { report(.ended, $0.location) }
    }

    private func scroller(_ layout: CanvasLayout) -> some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Color.clear
                // The artboard's rectangle as an element of its own, beside the container below
                // (not inside it, so the container's frame stays the one the app journeys read).
                Color.clear
                    .frame(width: layout.artboard.width, height: layout.artboard.height)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Artboard")
                    .accessibilityIdentifier("suite.canvas.artboard")
                    .padding(.leading, layout.origin.x)
                    .padding(.top, layout.origin.y)
                    .allowsHitTesting(false)
                ZStack(alignment: .topLeading) {
                    if checkerboard {
                        CanvasCheckerboard()
                    } else {
                        SuiteColor.artboard
                    }
                    content
                }
                .frame(width: layout.artboard.width, height: layout.artboard.height, alignment: .topLeading)
                .clipped()
                // Above the clip, so a selection's handles past the document's edge still show.
                .overlay(alignment: .topLeading) { overlay }
                .accessibilityElement(children: .contain)
                .suiteControl(id: "suite.canvas", enabled: true, reason: nil)
                .padding(.leading, layout.origin.x)
                .padding(.top, layout.origin.y)
            }
            .frame(width: layout.content.width, height: layout.content.height, alignment: .topLeading)
            .contentShape(.rect)
            .onContinuousHover { phase in hover(phase, layout) }
            .gesture(drag(layout), isEnabled: onDrag != nil)
            .simultaneousGesture(pan(layout), isEnabled: takesKeys)
            .simultaneousGesture(pinch(layout), isEnabled: zooms)
            .pointerStyle(panStart != nil ? .grabActive : spaceHeld ? .grabIdle : pointer)
        }
        // No scroll bars: the rulers show where the view is, and an unnamed bar fails the app audit (SJ21).
        .scrollIndicators(.never)
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, offset in scrolled = offset }
        // A pinch's scroll waits for the content's new size, or it would be clamped to the old one.
        .onScrollGeometryChange(for: CGSize.self) { $0.contentSize } action: { _, _ in
            guard let point = pendingScroll else { return }
            pendingScroll = nil
            position.scrollTo(point: point)
        }
        .background(SuiteColor.canvasSurround)
        .focusable(takesKeys)
        .focused($isFocused)
        .focusEffectDisabled()
        // Space let go while focus was elsewhere never arrives here.
        .onChange(of: isFocused) { _, focused in if !focused { spaceHeld = false } }
        .onKeyPress(phases: .all) { press in key(press, layout) }
    }

    /// Space (all its phases) arms the pan and stays here. Every other key reaches `onKey`
    /// going down, as before; an arrow it ignores pans the canvas.
    private func key(_ press: KeyPress, _ layout: CanvasLayout) -> KeyPress.Result {
        if press.key == .space {
            spaceHeld = press.phase != .up
            return .handled
        }
        guard press.phase == .down else { return .ignored }
        if let level = zoomKey(press) {
            zoomTo(level, layout)
            return .handled
        }
        if case .handled? = onKey?(press) { return .handled }
        guard press.modifiers.isDisjoint(with: [.command, .option, .control]),
            let offset = layout.panned(from: scrolled, key: press.key, page: press.modifiers.contains(.shift))
        else { return .ignored }
        position.scrollTo(point: offset)
        return .handled
    }

    /// The canvas takes focus and keys when the host handles keys or zoom.
    private var takesKeys: Bool { onKey != nil || zooms }

    /// Whether the host takes zooms, as a level or as a scale.
    private var zooms: Bool { onZoom != nil || onZoomLevel != nil }

    /// The level Command-plus (or Command-equals), Command-minus, Command-0 or Command-1 asks for
    /// (SuiteKernel's ZoomKey); nil for any other key, or when the host takes no zoom.
    private func zoomKey(_ press: KeyPress) -> ZoomLevel? {
        guard zooms,
            let key = ZoomKey(
                press.key.character, command: press.modifiers.contains(.command),
                option: press.modifiers.contains(.option), control: press.modifiers.contains(.control))
        else { return nil }
        return key.level(from: zoom, steps: ZoomMath.steps)
    }

    /// Hands `level` to the host: as it is through `onZoomLevel`, else as a scale through `onZoom`,
    /// the fit worked out here over the area inside the rulers.
    private func zoomTo(_ level: ZoomLevel, _ layout: CanvasLayout) {
        if let onZoomLevel { return onZoomLevel(level) }
        let area = CGSize(width: layout.viewport.width - layout.inset, height: layout.viewport.height - layout.inset)
        onZoom?(ZoomMath.scale(level, document: documentSize, in: area, using: fitScale))
    }

    private func hover(_ phase: HoverPhase, _ layout: CanvasLayout) {
        guard let onPointer else { return }
        switch phase {
        case .active(let location): onPointer(layout.artboardPoint(location))
        case .ended: onPointer(nil)
        }
    }

    /// A drag that starts with Space held scrolls with the pointer. It reads the pointer in
    /// window coordinates: the content's own coordinates move as it scrolls.
    private func pan(_ layout: CanvasLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard let start = panStart ?? (spaceHeld && last == nil ? scrolled : nil) else { return }
                panStart = start
                let eventTime = ProcessInfo.processInfo.systemUptime
                position.scrollTo(point: layout.panned(from: start, by: value.translation))
                report(eventTime)
            }
            .onEnded { _ in panStart = nil }
    }

    private func drag(_ layout: CanvasLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // A drag that starts with Space held is a pan; a tool drag under way keeps going.
                guard panStart == nil, last != nil || !spaceHeld else { return }
                if takesKeys { isFocused = true }
                let eventTime = ProcessInfo.processInfo.systemUptime
                let point = layout.documentPoint(value.location)
                onDrag?(last ?? layout.documentPoint(value.startLocation), point)
                last = point
                report(eventTime)
            }
            .onEnded { _ in
                guard last != nil else { return }
                last = nil
                onDragEnd?()
            }
    }

    /// A drag sample, shown by the next main-actor turn after the move (the
    /// host's update has run by then).
    private func report(_ eventTime: Double) {
        guard let probe else { return }
        Task { @MainActor in
            probe.record(CanvasProbe.sample(eventTime: eventTime, shownAt: ProcessInfo.processInfo.systemUptime))
        }
    }

    /// A pinch zooms about the pointer where it began, each step worked out from that start.
    private func pinch(_ layout: CanvasLayout) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let offset = pendingScroll ?? scrolled
                let start = pinchStart ?? (zoom, layout, offset,
                    CGPoint(x: value.startLocation.x - offset.x, y: value.startLocation.y - offset.y))
                pinchStart = start
                let next = ZoomMath.steps.snapped(start.zoom * value.magnification)
                // Held at the clamp or the 100% snap: no zoom, so no scroll either.
                guard next != zoom else { return }
                zoomTo(ZoomLevel(scale: next), layout)
                let target = CanvasLayout(
                    document: documentSize, zoom: next, viewport: start.layout.viewport, inset: start.layout.inset)
                let point = start.layout.anchoredOffset(to: target, pointer: start.pointer, scrolled: start.scrolled)
                if target.content == layout.content {
                    pendingScroll = nil
                    position.scrollTo(point: point)
                } else {
                    pendingScroll = point
                }
            }
            .onEnded { _ in pinchStart = nil }
    }
}

/// Where a CanvasViewport reports its drag samples (series `canvas-drag`,
/// SP2); a probe host sets it, and nil records nothing.
struct CanvasProbe: Sendable {
    static let dragSeries = "canvas-drag"
    let record: @MainActor @Sendable (ProbeSample) -> Void

    static func sample(eventTime: Double, shownAt: Double) -> ProbeSample {
        ProbeSample(series: dragSeries, eventTime: eventTime, shownAt: shownAt)
    }
}

extension EnvironmentValues {
    /// Where a CanvasViewport reports its drag samples; nil records nothing.
    var canvasProbe: CanvasProbe? {
        get { self[CanvasProbeKey.self] }
        set { self[CanvasProbeKey.self] = newValue }
    }
}

private struct CanvasProbeKey: EnvironmentKey {
    static let defaultValue: CanvasProbe? = nil
}
