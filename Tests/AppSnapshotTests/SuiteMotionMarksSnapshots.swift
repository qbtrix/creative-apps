// SuiteMotionMarksSnapshots.swift: SuiteUI's MotionPathMarks and GhostLayer
// on an artboard: a ball's dotted path with a dot per frame, two ghosts
// before it tinted onionBefore and one after tinted onionAfter, their
// opacity falling with distance, at zoom 1 and 2 (the dots keep their size).
// Writes suiteui-motion-marks-light.png and suiteui-motion-marks-dark.png,
// and checks the sheet against Golden/canvas/motion-marks-<appearance>.png in
// the four appearances (CM-15 commits the baselines). macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct SuiteMotionMarksSnapshots {
    @Test func motionPathAndGhostsAtZoomOneAndTwo() throws {
        try snapshot(MotionMarksSheet(), name: "suiteui-motion-marks-light", scheme: .light)
        try snapshot(MotionMarksSheet(), name: "suiteui-motion-marks-dark", scheme: .dark)
    }

    @Test func motionMarksGolden() {
        for appearance in SnapshotAppearance.allCases {
            assertGolden(
                MotionMarksSheet(), size: CGSize(width: 520, height: 220), name: "motion-marks", area: "canvas",
                appearance: appearance)
        }
    }
}

private struct MotionMarksSheet: View {
    /// The ball's position at each of seven frames, in document pixels.
    private static let frames: [CGPoint] = (0..<7).map { frame in
        let x = 12 + Double(frame) * 12
        return CGPoint(x: x, y: 60 - 40 * sin(Double(frame) / 6 * .pi))
    }
    /// The frame the playhead is on; ghosts show the two before and the one after.
    private static let current = 3

    var body: some View {
        HStack(spacing: SuiteSpacing.xxl) {
            ForEach([1.0, 2.0], id: \.self) { zoom in
                cell(zoom: zoom)
            }
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(SuiteColor.canvasSurround)
    }

    /// The artboard at `zoom`, clipped to the 200 x 150 pt cell.
    private func cell(zoom: Double) -> some View {
        ZStack(alignment: .topLeading) {
            SuiteColor.artboard
            MotionPathMarks(points: Self.frames, zoom: zoom)
            ForEach([-2, -1, 1], id: \.self) { offset in
                GhostLayer(
                    content: ball(offset < 0 ? SuiteColor.onionBefore : SuiteColor.onionAfter),
                    opacity: offset == -2 ? 0.2 : 0.4
                )
                .offset(position(Self.current + offset, zoom: zoom))
            }
            ball(SuiteColor.accent).offset(position(Self.current, zoom: zoom))
        }
        .frame(width: 200, height: 150, alignment: .topLeading)
        .clipped()
    }

    /// The ball's top-left corner at `frame`, so it is centred on the path's dot.
    private func position(_ frame: Int, zoom: Double) -> CGSize {
        let point = Self.frames.indices.contains(frame) ? Self.frames[frame] : .zero
        return CGSize(width: point.x * zoom - SuiteSize.selectionHandle, height: point.y * zoom - SuiteSize.selectionHandle)
    }

    private func ball(_ color: Color) -> some View {
        Circle().fill(color).frame(width: 2 * SuiteSize.selectionHandle, height: 2 * SuiteSize.selectionHandle)
    }
}
