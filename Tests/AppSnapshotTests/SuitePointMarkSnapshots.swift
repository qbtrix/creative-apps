// SuitePointMarkSnapshots.swift: CanvasPointMark (CM-7) over white and over
// black pixels at zoom 1 and 4, so the ring reads on both and stays the same
// size on screen while the pixels under it grow (#706's and #737's
// acceptance). Writes suiteui-point-mark-light.png and
// suiteui-point-mark-dark.png, and checks the four tiles against
// Golden/canvas/point-mark-<appearance>.png in the four appearances (CM-15
// commits the baselines).
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuitePointMarkSnapshots {
    @Test func pointMark() throws {
        try snapshot(PointMarkTiles().padding(SuiteSpacing.xxl), name: "suiteui-point-mark-light", scheme: .light)
        try snapshot(PointMarkTiles().padding(SuiteSpacing.xxl), name: "suiteui-point-mark-dark", scheme: .dark)
    }

    @Test func pointMarkGolden() {
        let size = CGSize(width: 400, height: 160)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(PointMarkTiles(), size: size, name: "point-mark", area: "canvas", appearance: appearance)
        }
    }
}

/// Four 30 × 30 px documents, white and black at zoom 1 and 4, each with the
/// mark on its centre pixel.
private struct PointMarkTiles: View {
    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.l) {
            ForEach([1.0, 4.0], id: \.self) { zoom in
                tile(Color.white, zoom: zoom)
                tile(Color.black, zoom: zoom)
            }
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func tile(_ pixels: Color, zoom: Double) -> some View {
        let side = 30 * zoom
        return ZStack(alignment: .topLeading) {
            pixels
            CanvasPointMark(point: CGPoint(x: 15, y: 15), zoom: zoom)
        }
        .frame(width: side, height: side)
    }
}
