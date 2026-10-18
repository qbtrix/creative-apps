// SuiteMotionMarksSnapshots.swift: a motion path's dots and line over a light
// and a dark artboard, with two ghosts at falling opacities behind the current
// drawing, in Light and Dark. Writes suiteui-motion-marks-light.png and
// suiteui-motion-marks-dark.png, checks the sheet against
// Golden/canvas/motion-<appearance>.png in the four appearances (CM-15 commits
// the baselines), and reads pixels: an ink dot sits on every frame point, and
// a ghost of ink over paper comes out at its opacity.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteMotionMarksSnapshots {
    static let sheet = CGSize(width: 360, height: 160)

    @Test func motionMarks() throws {
        try snapshot(MotionSheet(), name: "suiteui-motion-marks-light", scheme: .light)
        try snapshot(MotionSheet(), name: "suiteui-motion-marks-dark", scheme: .dark)
    }

    @Test func motionMarksGolden() {
        for appearance in SnapshotAppearance.allCases {
            assertGolden(MotionSheet(), size: Self.sheet, name: "motion", area: "canvas", appearance: appearance)
        }
    }

    /// Every frame point at zoom 2 has an ink dot on it, over the paper.
    @Test func aDotOnEveryFramePoint() throws {
        let points = [CGPoint(x: 10, y: 10), CGPoint(x: 30, y: 10), CGPoint(x: 50, y: 30)]
        let size = CGSize(width: 120, height: 80)
        let marks = MotionPathMarks(points: points, zoom: 2).background(SuiteColor.overlayPaper)
        let image = try #require(SnapshotHost(appearance: .light).image(marks, size: size))
        for point in points {
            #expect(Self.gray(image, at: CGPoint(x: point.x * 2, y: point.y * 2)) < 40, "no dot at \(point)")
        }
        // Clear of the dots and the line: paper.
        #expect(Self.gray(image, at: CGPoint(x: 100, y: 70)) > 215)
    }

    /// Ink in a ghost over paper reads as the opacity's share of ink.
    @Test(arguments: [0.25, 0.5, 1])
    func ghostDrawsAtItsOpacity(opacity: Double) throws {
        let size = CGSize(width: 40, height: 40)
        let ghost = GhostLayer(content: { SuiteColor.overlayInk }, opacity: opacity)
            .background(SuiteColor.overlayPaper)
        let image = try #require(SnapshotHost(appearance: .light).image(ghost, size: size))
        let expected = 255 * (1 - opacity)
        #expect(abs(Double(Self.gray(image, at: CGPoint(x: 20, y: 20))) - expected) <= 4)
    }

    /// The red channel at `point` (view points), black 0 to white 255.
    private static func gray(_ image: RGBAImage, at point: CGPoint) -> Int {
        let x = min(max(Int(point.x * SnapshotHost.scale), 0), image.width - 1)
        let y = min(max(Int(point.y * SnapshotHost.scale), 0), image.height - 1)
        return Int(image.bytes[(y * image.width + x) * 4])
    }
}

/// A light and a dark artboard, each with two ghosts, the current drawing and
/// its motion path.
private struct MotionSheet: View {
    private static let path = [
        CGPoint(x: 12, y: 50), CGPoint(x: 24, y: 34), CGPoint(x: 40, y: 24), CGPoint(x: 58, y: 22),
        CGPoint(x: 76, y: 28), CGPoint(x: 92, y: 40), CGPoint(x: 104, y: 56),
    ]

    var body: some View {
        HStack(spacing: SuiteSpacing.xxl) {
            artboard(SuiteColor.overlayPaper)
            artboard(SuiteColor.overlayInk)
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func artboard(_ fill: Color) -> some View {
        ZStack(alignment: .topLeading) {
            fill
            GhostLayer(content: { shape(at: Self.path[1], SuiteColor.onionBefore) }, opacity: 0.25)
            GhostLayer(content: { shape(at: Self.path[2], SuiteColor.onionBefore) }, opacity: 0.5)
            shape(at: Self.path[3], SuiteColor.accent)
            MotionPathMarks(points: Self.path, zoom: 1.25)
        }
        .frame(width: 140, height: 100)
        .clipped()
    }

    private func shape(at point: CGPoint, _ color: Color) -> some View {
        RoundedRectangle(cornerRadius: SuiteRadius.small)
            .fill(color)
            .frame(width: SuiteSize.rulerLabelSpacing / 2, height: SuiteSize.rulerLabelSpacing / 2)
            .offset(x: point.x * 1.25, y: point.y * 1.25)
    }
}
