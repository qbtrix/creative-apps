// CanvasViewport.swift: the canvas of an editor shell. The document (an
// image, an artboard) sits on a checkerboard at `zoom` points per document
// pixel, centred while it fits and scrollable with a margin once it doesn't,
// with rulers along the top and left that follow the zoom and the scroll
// (Ruler). Pointer drags arrive in document pixels: `onDrag(from:to:)` once
// per move with the previous and current point (a click is a drag that
// doesn't move), then `onDragEnd`. Pinch zooms through `onZoom`. Key presses
// reach `onKey` while the canvas has focus, which a drag on it gives it.
// While it has focus the canvas also pans without a scroll wheel: a drag that
// starts with Space held scrolls it with the pointer (the grab pointer) and
// never reaches `onDrag` or `onDragEnd`, and Space never reaches `onKey`; an
// arrow key `onKey` ignores scrolls a tenth of the viewport, Shift a whole
// one. Whether a drag pans is decided when it starts, so a tool drag always
// gets its `onDragEnd`. The host owns the zoom (the top bar and status bar
// show it) and learns the viewport's size from `onSize` to work out a fit.
// CanvasLayout is the placement and pan math, plain and tested on its own;
// every pan is clamped to its scrollable area. The content is clipped to the
// artboard; the overlay (selection outlines and handles, inline editors) is
// laid out on the artboard but not clipped, so marks on a shape that crosses
// the document's edge still show. Content, not chrome: flat, no glass. The
// artboard is the accessibility element `suite.canvas`.
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

    /// Non-positive document sides count as one pixel, as CanvasSurface does.
    public init(document: CGSize, zoom: Double, viewport: CGSize, margin: CGFloat = SuiteSpacing.xxl) {
        let scale = zoom.isFinite && zoom > 0 ? zoom : 1
        let artboard = CGSize(
            width: max(document.width, 1) * scale, height: max(document.height, 1) * scale)
        let content = CGSize(
            width: max(viewport.width, artboard.width + 2 * margin),
            height: max(viewport.height, artboard.height + 2 * margin))
        self.scale = scale
        self.artboard = artboard
        self.content = content
        self.viewport = viewport
        origin = CGPoint(x: (content.width - artboard.width) / 2, y: (content.height - artboard.height) / 2)
    }

    /// The document point under `point` in the scrollable area.
    public func documentPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - origin.x) / scale, y: (point.y - origin.y) / scale)
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

public struct CanvasViewport<Content: View, Overlay: View>: View {
    private let documentSize: CGSize
    private let zoom: Double
    private let pointer: PointerStyle?
    private let onSize: @MainActor (CGSize) -> Void
    private let onZoom: (@MainActor (Double) -> Void)?
    private let onDrag: (@MainActor (CGPoint, CGPoint) -> Void)?
    private let onDragEnd: (@MainActor () -> Void)?
    private let onKey: (@MainActor (KeyPress) -> KeyPress.Result)?
    private let content: Content
    private let overlay: Overlay
    @State private var scrolled: CGPoint = .zero
    @State private var last: CGPoint?
    @State private var pinchBase: Double?
    @State private var position = ScrollPosition()
    @State private var spaceHeld = false
    /// The scroll offset where the pan under way began; nil while no pan is.
    @State private var panStart: CGPoint?
    @FocusState private var isFocused: Bool

    /// `documentSize` in pixels; `content` and `overlay` are laid out at the
    /// artboard's size (the document at `zoom`), overlay on top. Only the
    /// content is clipped to the artboard.
    public init(
        documentSize: CGSize, zoom: Double, pointer: PointerStyle? = nil,
        onSize: @escaping @MainActor (CGSize) -> Void = { _ in },
        onZoom: (@MainActor (Double) -> Void)? = nil,
        onDrag: (@MainActor (CGPoint, CGPoint) -> Void)? = nil,
        onDragEnd: (@MainActor () -> Void)? = nil,
        onKey: (@MainActor (KeyPress) -> KeyPress.Result)? = nil,
        @ViewBuilder content: () -> Content, @ViewBuilder overlay: () -> Overlay
    ) {
        self.documentSize = documentSize
        self.zoom = zoom
        self.pointer = pointer
        self.onSize = onSize
        self.onZoom = onZoom
        self.onDrag = onDrag
        self.onDragEnd = onDragEnd
        self.onKey = onKey
        self.content = content()
        self.overlay = overlay()
    }

    public var body: some View {
        GeometryReader { geometry in
            let viewport = CGSize(
                width: max(geometry.size.width - SuiteSize.ruler, 0),
                height: max(geometry.size.height - SuiteSize.ruler, 0))
            let layout = CanvasLayout(document: documentSize, zoom: zoom, viewport: viewport)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    corner
                    Ruler(axis: .horizontal, origin: layout.origin.x - scrolled.x, scale: layout.scale)
                }
                HStack(spacing: 0) {
                    Ruler(axis: .vertical, origin: layout.origin.y - scrolled.y, scale: layout.scale)
                    scroller(layout)
                }
            }
            .onAppear { onSize(viewport) }
            .onChange(of: viewport) { _, size in onSize(size) }
        }
    }

    /// The ruler corner, naming the unit.
    private var corner: some View {
        Text("px")
            .font(SuiteFont.rulerLabel)
            .foregroundStyle(SuiteColor.secondaryText)
            .frame(width: SuiteSize.ruler, height: SuiteSize.ruler)
            .background(SuiteColor.panel)
            .accessibilityHidden(true)
    }

    private func scroller(_ layout: CanvasLayout) -> some View {
        ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                Color.clear
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(ImagePaint(image: Self.checkerboard))
                    content
                }
                .frame(width: layout.artboard.width, height: layout.artboard.height, alignment: .topLeading)
                .clipped()
                // Above the clip, so a selection's handles past the document's edge still show.
                .overlay(alignment: .topLeading) { overlay }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("suite.canvas")
                .padding(.leading, layout.origin.x)
                .padding(.top, layout.origin.y)
            }
            .frame(width: layout.content.width, height: layout.content.height, alignment: .topLeading)
            .contentShape(.rect)
            .gesture(drag(layout), isEnabled: onDrag != nil)
            .simultaneousGesture(pan(layout), isEnabled: onKey != nil)
            .simultaneousGesture(pinch, isEnabled: onZoom != nil)
            .pointerStyle(panStart != nil ? .grabActive : spaceHeld ? .grabIdle : pointer)
        }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, offset in scrolled = offset }
        .background(SuiteColor.canvasSurround)
        .focusable(onKey != nil)
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
        if case .handled? = onKey?(press) { return .handled }
        guard press.modifiers.isDisjoint(with: [.command, .option, .control]),
            let offset = layout.panned(from: scrolled, key: press.key, page: press.modifiers.contains(.shift))
        else { return .ignored }
        position.scrollTo(point: offset)
        return .handled
    }

    /// A drag that starts with Space held scrolls with the pointer. It reads the pointer in
    /// window coordinates: the content's own coordinates move as it scrolls.
    private func pan(_ layout: CanvasLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard let start = panStart ?? (spaceHeld && last == nil ? scrolled : nil) else { return }
                panStart = start
                position.scrollTo(point: layout.panned(from: start, by: value.translation))
            }
            .onEnded { _ in panStart = nil }
    }

    private func drag(_ layout: CanvasLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // A drag that starts with Space held is a pan; a tool drag under way keeps going.
                guard panStart == nil, last != nil || !spaceHeld else { return }
                if onKey != nil { isFocused = true }
                let point = layout.documentPoint(value.location)
                onDrag?(last ?? layout.documentPoint(value.startLocation), point)
                last = point
            }
            .onEnded { _ in
                guard last != nil else { return }
                last = nil
                onDragEnd?()
            }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBase ?? zoom
                pinchBase = base
                onZoom?(base * value.magnification)
            }
            .onEnded { _ in pinchBase = nil }
    }

    /// Two squares of each checker tone, tiled behind the document.
    private static var checkerboard: Image {
        let square = SuiteSize.checkerSquare
        return Image(size: CGSize(width: 2 * square, height: 2 * square)) { context in
            context.fill(
                Path(CGRect(x: 0, y: 0, width: 2 * square, height: 2 * square)), with: .color(SuiteColor.checkerDark))
            context.fill(Path(CGRect(x: 0, y: 0, width: square, height: square)), with: .color(SuiteColor.checkerLight))
            context.fill(
                Path(CGRect(x: square, y: square, width: square, height: square)), with: .color(SuiteColor.checkerLight))
        }
    }
}
