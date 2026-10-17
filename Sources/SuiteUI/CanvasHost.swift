// CanvasHost.swift: CanvasHostView in SwiftUI (canvas-host CH-3), on the CH-1
// contract. Keys go through `onKeyPress` on the focusable host, since AppKit
// can't build the `KeyPress` the delegate takes. macOS only.
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
