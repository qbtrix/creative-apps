// CanvasViewport+Host.swift: a CanvasViewport whose content is a CanvasHost
// (canvas-host CH-9). The viewport keeps its own container ids,
// `suite.canvas` and `suite.canvas.artboard`, and its zoom, rulers and size
// reporting; the host inside it draws the tiles and takes the pointer (no
// `onDrag`, so the viewport adds no drag gesture over the host's NSView). The
// host view also names itself `suite.canvas`, as a child of the container;
// its scroll wheel pans the host itself. The existing initializer and every
// app's viewport are untouched.
import SwiftUI

extension CanvasViewport where Content == CanvasHost, Overlay == EmptyView {
    /// A viewport over `content`, drawn and driven by a CanvasHost that sends input to `delegate`.
    public init(
        host content: any CanvasContentProviding,
        delegate: (any CanvasInputDelegate)?,
        zoom: Double,
        checkerboard: Bool = false,
        unit: String = "px",
        onSize: @escaping @MainActor (CGSize) -> Void = { _ in },
        onZoom: (@MainActor (Double) -> Void)? = nil,
        onPointer: (@MainActor (CGPoint?) -> Void)? = nil
    ) {
        self.init(
            documentSize: content.documentSize, zoom: zoom, checkerboard: checkerboard, unit: unit,
            onSize: onSize, onZoom: onZoom, onPointer: onPointer,
            content: { CanvasHost(content: content, delegate: delegate) },
            overlay: { EmptyView() })
    }
}
