// GalleryTransform.swift: the gallery's `transform-handles` page
// (transform-tools TT-2). A local 200 × 120 TransformBox at (100, 80) on the
// 400 × 300 document, its SelectionHandlesEditor (given the box's turn, which
// TT-2 ignores) and TransformRows beside it. A handle drag resizes the local
// box and logs the box on its end; a knob drag logs its turn. TT-7 runs the
// page's intents through TransformCommands on a live target instead. The
// box is the element `suite.gallery.transform-box`; the log is
// `suite.gallery.log`.
import SuiteKernel
import SwiftUI

/// `transform-handles`: one box, its handles and the transform rows.
struct GalleryTransformPage: View {
    @State private var item = TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200))
    @State private var turned: Double?
    @State private var log = GalleryCanvasLog()

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            HStack(alignment: .top, spacing: SuiteSpacing.m) {
                CanvasViewport(documentSize: GalleryCanvas.document, zoom: 1) {
                    SuiteColor.artboard
                } overlay: {
                    ZStack(alignment: .topLeading) {
                        ProbeElement("suite.gallery.transform-box", label: "Transform box", rect: rect)
                        SelectionOutline(rect: rect, zoom: 1)
                        SelectionHandlesEditor(rect: rect, degrees: item.degrees, zoom: 1, onResize: resize,
                                               onRotate: { turned = $0 }, onEnd: endDrag)
                    }
                }
                TransformRows(selection: item, help: nil, flipHelp: nil) { log.add($0.command.id) }
                    .frame(width: SuiteSize.inspectorWidth.ideal)
            }
            GalleryCanvasLogLine(log: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.panel)
    }

    /// The local box in document pixels, as the handles take it.
    private var rect: CGRect {
        let b = item.box
        return CGRect(x: b.minX, y: b.minY, width: b.width, height: b.height)
    }

    private func resize(_ next: CGRect) {
        item.box = Rect(minX: Double(next.minX), minY: Double(next.minY), maxX: Double(next.maxX), maxY: Double(next.maxY))
    }

    private func endDrag() {
        if let turned {
            log.ended("rotate \(Int(turned.rounded()))")
        } else {
            log.ended("rect \(GalleryCanvas.point(rect.origin)) \(GalleryCanvas.size(rect.size))")
        }
        turned = nil
    }
}
