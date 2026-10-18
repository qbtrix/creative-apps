// SuiteEditorKernelSnapshots.swift (editor-kernel EK-5): SelectionHandles and
// SnapGuideMarks over a CanvasViewport at 200%, in Light and Dark. The handles
// sit around one box with the top-left one hovered; the guides are the
// kernel's `SnapGuides.fake` between two boxes: a line at x 300 and two gaps
// labelled 100. Writes suiteui-editor-kernel-handles-{light,dark}.png and
// suiteui-editor-kernel-guides-{light,dark}.png. Where each handle sits is the
// kernel's `BoxMath.handles`; until EK-20 lands its body (a stub returning no
// handles), the test uses `fixtureHandles`, test data in the same shape.
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteEditorKernelSnapshots {
    static let box = Rect(minX: 40, minY: 60, maxX: 240, maxY: 180)

    /// One 4-pixel square per handle around `box`, the rotate knob 12 above
    /// the top edge: the same shape `BoxMath.handles(of:size:)` returns.
    static let fixtureHandles: [EditorHandle: Rect] = {
        let b = box, midX = (b.minX + b.maxX) / 2, midY = (b.minY + b.maxY) / 2
        let centres: [EditorHandle: (Double, Double)] = [
            .topLeft: (b.minX, b.minY), .top: (midX, b.minY), .topRight: (b.maxX, b.minY),
            .right: (b.maxX, midY), .bottomRight: (b.maxX, b.maxY), .bottom: (midX, b.maxY),
            .bottomLeft: (b.minX, b.maxY), .left: (b.minX, midY), .rotate: (midX, b.minY - 12),
        ]
        return centres.mapValues { Rect(minX: $0.0 - 2, minY: $0.1 - 2, maxX: $0.0 + 2, maxY: $0.1 + 2) }
    }()

    /// The kernel's handles once EK-20 lands, the fixture until then.
    static var boxHandles: [EditorHandle: Rect] {
        let kernel = BoxMath.handles(of: box, size: 4)
        return kernel.isEmpty ? fixtureHandles : kernel
    }

    @Test func handleMarks() throws {
        let marks = SelectionHandles.marks(handles: Self.boxHandles, zoom: 2)
        let names = marks.map { SelectionHandles.name($0.handle) }
        #expect(names == ["topLeft", "top", "topRight", "right", "bottomRight", "bottom", "bottomLeft", "left", "rotate"])
        #expect(marks.allSatisfy { $0.frame.width == SuiteSize.selectionHandle })
        let topLeft = try #require(marks.first)
        #expect(topLeft.frame.midX == 80 && topLeft.frame.midY == 120)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(HandlesSample(), name: "suiteui-editor-kernel-handles-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func guideMarks() throws {
        let labels = SnapGuideMarks.labels(.fake, zoom: 2)
        #expect(labels.map(\.text) == ["100", "100"])
        #expect(labels.first?.center == CGPoint(x: 500, y: 300))
        #expect(SnapGuideMarks.accessibilityValue(.fake) == SnapGuides.fake.summary)
        #expect(SnapGuideMarks.accessibilityValue(.fake) == "x 300, gap x 100, spacing x 100")
        #expect(!SnapGuideMarks.lines(.fake, zoom: 2).isEmpty)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(GuidesSample(), name: "suiteui-editor-kernel-guides-\(scheme.name)", scheme: scheme)
        }
    }
}

/// The handles around one box in a CanvasViewport's overlay at 200%, top-left hovered.
private struct HandlesSample: View {
    let zoom = 2.0

    var body: some View {
        CanvasViewport(documentSize: CGSize(width: 280, height: 220), zoom: zoom, checkerboard: false) {
            BoxesSample(boxes: [SuiteEditorKernelSnapshots.box], zoom: zoom)
        } overlay: {
            SelectionHandles(box: SuiteEditorKernelSnapshots.box, handles: SuiteEditorKernelSnapshots.boxHandles,
                             zoom: zoom, hovered: .topLeft)
        }
    }
}

/// `SnapGuides.fake` between two boxes (the line on the right one's left edge) in a CanvasViewport's overlay at 100%.
private struct GuidesSample: View {
    let zoom = 1.0

    var body: some View {
        CanvasViewport(documentSize: CGSize(width: 480, height: 440), zoom: zoom, checkerboard: false) {
            BoxesSample(boxes: [Rect(minX: 100, minY: 100, maxX: 200, maxY: 200),
                                Rect(minX: 300, minY: 100, maxX: 400, maxY: 400)], zoom: zoom)
        } overlay: {
            SnapGuideMarks(guides: .fake, zoom: zoom)
        }
    }
}

/// Plain outlined boxes in document pixels, the layers the marks sit on.
private struct BoxesSample: View {
    let boxes: [Rect]
    let zoom: Double

    var body: some View {
        Path { path in
            for box in boxes { path.addRect(SelectionHandles.viewRect(box, zoom: zoom)) }
        }
        .stroke(SuiteColor.outline, lineWidth: 1)
    }
}
