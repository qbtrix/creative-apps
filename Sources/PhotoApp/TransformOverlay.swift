// TransformOverlay.swift: Free Transform's box over the canvas (transform
// PT-2). Nothing while the workspace has no transform draft; with one, the
// element `photo.canvas.transform-box`, "Transform box", at the draft's
// unturned box, and SuiteUI's SelectionHandlesEditor on it, turned with the
// draft. A handle drag asks for `.set` with the box it gives (keeping the
// turn and flips); a knob drag asks for `.set` with the box turned from where
// the drag began. Every sample of one drag carries one token, so the draft
// records one step per gesture. Mid-drag it draws the window's live
// transform (LiveTransformCopy+Kernel.swift) when there is one and holds it
// with every sample, so a resting pointer doesn't hand it back; the release
// sends `endDrag` so the window takes it back. Values in, intents out.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct TransformOverlay: View {
    let model: PhotoWorkspace
    let zoom: Double
    var perform: PhotoPerform = { _ in }
    /// The running drag's token and the turn it began from; nil between drags.
    @State private var gesture: (token: String, degrees: Double)?
    @Environment(\.photoLiveTransform) private var live

    /// The transform box's element; nil without a transform draft.
    var mark: PhotoCanvasMark? { Self.box(model).map { PhotoCanvasMark.transformBox(Self.rect($0.box)) } }

    /// The draft's box as the kernel sees it; nil without a draft.
    private nonisolated static func box(_ model: PhotoWorkspace) -> TransformBox? {
        model.transformDraft == nil ? nil : model.transformSelection
    }

    var body: some View {
        if let box = Self.box(live?.shown ?? model) {
            let mark = PhotoCanvasMark.transformBox(Self.rect(box.box))
            ZStack(alignment: .topLeading) {
                mark.probe(zoom: zoom)
                SelectionHandlesEditor(rect: mark.rect, degrees: box.degrees, zoom: zoom, onResize: { resize(box, to: $0) },
                                       onRotate: { turn(box, by: $0) }, onEnd: end)
            }
        }
    }

    /// A drag's release: its token goes, and the window takes the live transform back.
    private func end() {
        gesture = nil
        perform(.transform(.endDrag))
    }

    /// A handle drag: the box it gives, with the draft's turn and flips.
    private func resize(_ current: TransformBox, to rect: CGRect) {
        var next = current
        next.box = Rect(minX: Double(rect.minX), minY: Double(rect.minY), maxX: Double(rect.maxX), maxY: Double(rect.maxY))
        perform(.transform(.kernel(.set(next, drag: token(current)))))
    }

    /// A knob drag: `degrees` turned since the drag began.
    private func turn(_ current: TransformBox, by degrees: Double) {
        let token = token(current)
        var start = current
        start.degrees = gesture?.degrees ?? current.degrees
        perform(.transform(.kernel(.set(TransformRules.rotated(start, by: degrees), drag: token))))
    }

    /// The running drag's token, starting one (from `current`'s turn) on its first sample; holds the live
    /// transform until the release, pointer down.
    private func token(_ current: TransformBox) -> String {
        live?.hold()
        if let gesture { return gesture.token }
        let token = UUID().uuidString
        gesture = (token, current.degrees)
        return token
    }

    /// A kernel box in document pixels as a CGRect.
    private nonisolated static func rect(_ b: Rect) -> CGRect { CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height) }
}
