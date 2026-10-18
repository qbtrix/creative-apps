// SuitePathMarksSnapshots.swift: PathMarks (corner squares, smooth circles,
// curve handles) and GuideMarks across the viewport, over an artboard at zoom
// 1 and 2, in Light and Dark. Writes suiteui-path-marks-light.png and
// suiteui-path-marks-dark.png, and checks the zoom 1 card against
// Golden/canvas/path-marks-<appearance>.png in the four appearances (CM-14
// commits the baselines).
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuitePathMarksSnapshots {
    @Test func pathMarks() throws {
        try snapshot(PathMarksSheet(), name: "suiteui-path-marks-light", scheme: .light)
        try snapshot(PathMarksSheet(), name: "suiteui-path-marks-dark", scheme: .dark)
    }

    @Test func pathMarksGolden() {
        let size = PathMarksCard.size(zoom: 1)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(PathMarksCard(zoom: 1), size: size, name: "path-marks", area: "canvas", appearance: appearance)
        }
    }
}

/// A closed pen path of two corners and two smooth points, with one guide
/// each way, on a white artboard inset in the window background.
private struct PathMarksCard: View {
    let zoom: Double

    static let document = CGSize(width: 200, height: 140)
    static let inset: CGFloat = 40

    static func size(zoom: Double) -> CGSize {
        CGSize(width: document.width * zoom + inset * 2, height: document.height * zoom + inset * 2)
    }

    private let anchors = [
        PathMarkAnchor(CGPoint(x: 30, y: 110)),
        PathMarkAnchor(CGPoint(x: 60, y: 30), kind: .smooth,
                       handleIn: CGPoint(x: 35, y: 45), handleOut: CGPoint(x: 85, y: 15)),
        PathMarkAnchor(CGPoint(x: 140, y: 40), kind: .smooth,
                       handleIn: CGPoint(x: 115, y: 25), handleOut: CGPoint(x: 165, y: 55)),
        PathMarkAnchor(CGPoint(x: 170, y: 110)),
    ]
    private let segments = [
        PathMarkSegment(from: 0, to: 1), PathMarkSegment(from: 1, to: 2),
        PathMarkSegment(from: 2, to: 3), PathMarkSegment(from: 3, to: 0),
    ]

    var body: some View {
        let size = Self.size(zoom: zoom)
        let viewport = CGRect(x: -Self.inset, y: -Self.inset, width: size.width, height: size.height)
        Rectangle()
            .fill(SuiteColor.artboard)
            .frame(width: Self.document.width * zoom, height: Self.document.height * zoom)
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .topLeading) {
                    GuideMarks(guides: [.vertical(100), .horizontal(70)], zoom: zoom, viewport: viewport)
                    PathMarks(anchors: anchors, segments: segments, zoom: zoom)
                }
            }
            .frame(width: size.width, height: size.height)
            .background(SuiteColor.windowBackground)
    }
}

private struct PathMarksSheet: View {
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            PathMarksCard(zoom: 1)
            PathMarksCard(zoom: 2)
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
