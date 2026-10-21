// CanvasMarks+Area.swift (area-selection AR-7): an area selection's marching
// ants, drawn in a CanvasViewport's overlay. `AreaAnts` strokes each closed
// contour of the selection's outline (`AreaMask.outline`) as a dashed
// `overlayInk` line over a solid `overlayPaper` one, so the ants read on any
// pixels, plus a lasso or polygon in progress as a rubber band that closes
// back to its first point once it has three. The dash marches one `xxs` step
// 4 times a second (one dash cycle a second) and stands still under Reduce
// Motion and in snapshot renders. Positions are document pixels at the canvas
// zoom; a zoom that isn't a positive finite number counts as 1. Marks are
// hidden from accessibility and never take a click. The geometry and the
// phase are static, plain and nonisolated so tests read them without
// rendering. Path strokes only: no immediate-mode drawing per tick.
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

    /// `outline` is the selection's closed contours and `draft` the outline being drawn, both in document pixels;
    /// `zoom` in points per pixel.
    public init(outline: [[Point]], draft: [Point] = [], zoom: Double) {
        (self.outline, self.draft, self.zoom) = (outline, draft, zoom)
    }

    /// `zoom`, or 1 when it isn't a positive finite number.
    public nonisolated static func scale(_ zoom: Double) -> Double {
        zoom.isFinite && zoom > 0 ? zoom : 1
    }

    /// Each contour in view points at `zoom`, in order.
    public nonisolated static func lines(_ outline: [[Point]], zoom: Double) -> [[CGPoint]] {
        let factor = scale(zoom)
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

    /// The dash phase at `time` seconds: one `xxs` step per tick, back to 0 after a dash cycle; 0 under Reduce
    /// Motion or when `time` isn't finite.
    public nonisolated static func phase(at time: TimeInterval, reduceMotion: Bool) -> CGFloat {
        guard !reduceMotion, time.isFinite else { return 0 }
        let steps = Int((dash.reduce(0, +) / SuiteSpacing.xxs).rounded())
        guard steps > 0 else { return 0 }
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
