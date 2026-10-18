// CanvasHost.swift: CanvasHostView in SwiftUI (canvas-host CH-3), on the CH-1
// contract. Keys go through `onKeyPress` on the focusable host, since AppKit
// can't build the `KeyPress` the delegate takes. EmbeddedCanvasHost puts the
// view inside a CanvasViewport's content instead (render adoption R1): the
// viewport keeps the pointer and keys, the app pushes tiles straight to the
// view it is handed (no SwiftUI update per frame), and the view follows the
// rendering preference onto Metal or the tile layers. macOS only.
import AppKit
import SwiftUI

/// A document on the canvas: tiles drawn by AppKit layers, input sent to `delegate`.
public struct CanvasHost: View {
    let content: any CanvasContentProviding
    let delegate: (any CanvasInputDelegate)?

    public init(content: any CanvasContentProviding, delegate: (any CanvasInputDelegate)?) {
        (self.content, self.delegate) = (content, delegate)
    }

    public var body: some View {
        CanvasHostRepresentable(content: content, delegate: delegate)
            .focusable()
            .focusEffectDisabled()
            .onKeyPress(phases: .down) { press in delegate?.key(press) ?? .ignored }
    }
}

/// An update hands the view the delegate and the content's dirty tiles.
struct CanvasHostRepresentable: NSViewRepresentable {
    let content: any CanvasContentProviding
    let delegate: (any CanvasInputDelegate)?

    func makeNSView(context: Context) -> CanvasHostView { CanvasHostView(frame: .zero) }

    func updateNSView(_ view: CanvasHostView, context: Context) {
        view.delegate = delegate
        view.show(content)
    }
}

/// A CanvasHostView inside a CanvasViewport's content (`isEmbedded`), turned by `degrees`. `attach`
/// hands the app the view on every update, so it shows tiles with `show` directly; with a `rendering`
/// preference the view draws on Metal or the tile layers as the preference says.
public struct EmbeddedCanvasHost: NSViewRepresentable {
    let degrees: Double
    let rendering: (any RenderingPreferenceReading)?
    let attach: @MainActor (CanvasHostView) -> Void

    public init(degrees: Double = 0, rendering: (any RenderingPreferenceReading)? = nil,
                attach: @escaping @MainActor (CanvasHostView) -> Void) {
        (self.degrees, self.rendering, self.attach) = (degrees, rendering, attach)
    }

    public func makeNSView(context: Context) -> CanvasHostView {
        let view = CanvasHostView(frame: .zero)
        view.isEmbedded = true
        view.rotationDegrees = degrees
        if let rendering { view.followRendering(rendering) }
        attach(view)
        return view
    }

    public func updateNSView(_ view: CanvasHostView, context: Context) {
        view.rotationDegrees = degrees
        attach(view)
    }
}
