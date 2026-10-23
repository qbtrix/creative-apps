// SuitePathMarksSnapshots.swift (CM-5): PathMarks and ViewportGuideMarks over
// a CanvasViewport's sample artboard at 200%, in Light and Dark: a closed path
// with two corner anchors (squares) and two smooth anchors (circles with their
// handles), and one vertical and one horizontal guide across the artboard.
// Writes suiteui-path-marks-{light,dark}.png. The golden (QB-V5) is the same
// marks on a plain artboard at 240 × 160 pt in the four appearances:
// Golden/canvas/suite-path-marks-{light,dark,light-ic,dark-ic}.png.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuitePathMarksSnapshots {
    /// A lens-like shape in document pixels: corners left and right, smooth top and bottom.
    static let anchors = [
        PathAnchor(point: CGPoint(x: 20, y: 60), kind: .corner),
        PathAnchor(point: CGPoint(x: 80, y: 20), kind: .smooth,
                   handleIn: CGPoint(x: 50, y: 20), handleOut: CGPoint(x: 110, y: 20)),
        PathAnchor(point: CGPoint(x: 140, y: 60), kind: .corner),
        PathAnchor(point: CGPoint(x: 80, y: 100), kind: .smooth,
                   handleIn: CGPoint(x: 110, y: 100), handleOut: CGPoint(x: 50, y: 100)),
    ]
    static let segments = [
        PathSegment(from: 0, to: 1), PathSegment(from: 1, to: 2),
        PathSegment(from: 2, to: 3), PathSegment(from: 3, to: 0),
    ]
    static let guides: [ViewportGuide] = [.vertical(x: 80), .horizontal(y: 60)]

    @Test func pathMarks() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(PathMarksSample(), name: "suiteui-path-marks-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func pathMarksGolden() {
        let size = CGSize(width: 240, height: 160)
        let zoom = 1.5
        let marks = ZStack(alignment: .topLeading) {
            SuiteColor.artboard
            ViewportGuideMarks(guides: Self.guides, zoom: zoom, viewport: CGRect(origin: .zero, size: size))
            PathMarks(anchors: Self.anchors, segments: Self.segments, zoom: zoom)
        }
        for appearance in SnapshotAppearance.allCases {
            assertGolden(marks, size: size, name: "suite-path-marks", area: "canvas", appearance: appearance)
        }
    }
}

/// The marks in a CanvasViewport's overlay at 200%; no state.
private struct PathMarksSample: View {
    let document = CGSize(width: 400, height: 300)
    let zoom = 2.0

    var body: some View {
        CanvasViewport(documentSize: document, zoom: zoom, checkerboard: false) {
            EmptyView()
        } overlay: {
            ZStack(alignment: .topLeading) {
                ViewportGuideMarks(guides: SuitePathMarksSnapshots.guides, zoom: zoom,
                                   viewport: CGRect(x: 0, y: 0, width: document.width * zoom, height: document.height * zoom))
                PathMarks(anchors: SuitePathMarksSnapshots.anchors, segments: SuitePathMarksSnapshots.segments, zoom: zoom)
            }
        }
    }
}
