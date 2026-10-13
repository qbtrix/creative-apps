// CanvasViewport.swift: the canvas of an editor shell. The document (an
// image, an artboard) sits on a checkerboard at `zoom` points per document
// pixel, centred while it fits and scrollable with a margin once it doesn't,
// with rulers along the top and left that follow the zoom and the scroll
// (Ruler). Pointer drags arrive in document pixels: `onDrag(from:to:)` once
// per move with the previous and current point (a click is a drag that
// doesn't move), then `onDragEnd`. Pinch zooms through `onZoom`. Key presses
// reach `onKey` while the canvas has focus, which a drag on it gives it. The
// host owns the zoom (the top bar and status bar show it) and learns the
// viewport's size from `onSize` to work out a fit. CanvasLayout is the
// placement math, plain and tested on its own. The content is clipped to the
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
        origin = CGPoint(x: (content.width - artboard.width) / 2, y: (content.height - artboard.height) / 2)
    }

    /// The document point under `point` in the scrollable area.
    public func documentPoint(_ point: CGPoint) -> CGPoint {
        CGPoint(x: (point.x - origin.x) / scale, y: (point.y - origin.y) / scale)
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
            .simultaneousGesture(pinch, isEnabled: onZoom != nil)
            .pointerStyle(pointer)
        }
        .onScrollGeometryChange(for: CGPoint.self) { $0.contentOffset } action: { _, offset in scrolled = offset }
        .background(SuiteColor.canvasSurround)
        .focusable(onKey != nil)
        .focused($isFocused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in onKey?(press) ?? .ignored }
    }

    private func drag(_ layout: CanvasLayout) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if onKey != nil { isFocused = true }
                let point = layout.documentPoint(value.location)
                onDrag?(last ?? layout.documentPoint(value.startLocation), point)
                last = point
            }
            .onEnded { _ in
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
