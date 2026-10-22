// CanvasMarks+Area.swift (area-selection AR-7): marching ants in a CanvasViewport's overlay. `AreaAnts` strokes each
// closed contour of the outline as dashed `overlayInk` over solid `overlayPaper`, plus a lasso or polygon in progress
// as a rubber band closed back to its first point once it has three. The dash steps `xxs` 4 times a second and stands
// still under Reduce Motion and in snapshots. Document pixels at the canvas zoom (a bad zoom is 1); hidden from
// accessibility, never hit. Geometry and phase are static and nonisolated for tests. Path strokes only.
import SuiteKernel
import SwiftUI

/// The marching ants around an area selection and the outline being drawn.
public struct AreaAnts: View {
    private let outline: [[Point]], draft: [Point], zoom: Double
    @Environment(\.suiteReduceMotion) private var reduceMotion
    @Environment(\.suiteSnapshotRendering) private var snapshot

    /// How many times a second the dash steps.
    public nonisolated static let stepsPerSecond = 4.0
    /// The dash: on and off the same length.
    nonisolated static let dash: [CGFloat] = [SuiteSpacing.xs, SuiteSpacing.xs]

    /// `outline`'s closed contours and the `draft` being drawn, in document pixels; `zoom` in points per pixel.
    public init(outline: [[Point]], draft: [Point] = [], zoom: Double) {
        (self.outline, self.draft, self.zoom) = (outline, draft, zoom)
    }

    /// Each contour in view points at `zoom` (1 when it isn't a positive finite number), in order.
    public nonisolated static func lines(_ outline: [[Point]], zoom: Double) -> [[CGPoint]] {
        let factor = zoom.isFinite && zoom > 0 ? zoom : 1
        return outline.map { $0.map { CGPoint(x: $0.x * factor, y: $0.y * factor) } }
    }

    /// The outline being drawn in view points, closed back to its first point once it has three.
    public nonisolated static func band(_ draft: [Point], zoom: Double) -> [CGPoint] {
        let line = lines([draft], zoom: zoom).first ?? []
        guard line.count >= 3, let first = line.first else { return line }
        return line + [first]
    }

    /// Whether the ants march: not under Reduce Motion, nor in a snapshot render.
    public nonisolated static func animates(reduceMotion: Bool, snapshot: Bool) -> Bool {
        !reduceMotion && !snapshot
    }

    /// The dash phase at `time` seconds: one `xxs` step per tick, a dash cycle a second; 0 under Reduce Motion.
    public nonisolated static func phase(at time: TimeInterval, reduceMotion: Bool) -> CGFloat {
        let steps = Int((dash.reduce(0, +) / SuiteSpacing.xxs).rounded())
        guard !reduceMotion, time.isFinite, steps > 0 else { return 0 }
        let tick = Int((time * stepsPerSecond).rounded(.down).truncatingRemainder(dividingBy: Double(steps)))
        return CGFloat((tick + steps) % steps) * SuiteSpacing.xxs
    }

    public var body: some View {
        Group {
            if Self.animates(reduceMotion: reduceMotion, snapshot: snapshot) {
                TimelineView(.periodic(from: .now, by: 1 / Self.stepsPerSecond)) { context in
                    marks(Self.phase(at: context.date.timeIntervalSinceReferenceDate, reduceMotion: false))
                }
            } else {
                marks(0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func marks(_ phase: CGFloat) -> some View {
        let shape = AreaAntsShape(contours: Self.lines(outline, zoom: zoom), band: Self.band(draft, zoom: zoom))
        return ZStack {
            shape.stroke(SuiteColor.overlayPaper, lineWidth: 1)
            shape.stroke(SuiteColor.overlayInk, style: StrokeStyle(lineWidth: 1, dash: Self.dash, dashPhase: phase))
        }
    }
}

/// Each contour as a closed polyline, then the band as drawn.
private struct AreaAntsShape: Shape {
    let contours: [[CGPoint]], band: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for contour in contours where contour.count > 1 {
            path.addLines(contour)
            path.closeSubpath()
        }
        if band.count > 1 { path.addLines(band) }
        return path
    }
}
