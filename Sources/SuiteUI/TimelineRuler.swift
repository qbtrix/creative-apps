// TimelineRuler.swift: the frame ruler above TimelineStrip's lanes. Draws only
// the ticks and labels inside the scrolled-to stretch (FrameMapping.rulerMarks),
// so a long duration costs no more than a short one. A drag anywhere on it
// scrubs; VoiceOver reads and steps the playhead frame.
import SwiftUI

struct TimelineRuler: View {
    let mapping: FrameMapping
    /// The stretch of the lanes the scroll view shows, in mapping x; nil until
    /// it first reports.
    let visibleX: ClosedRange<Double>?
    let playhead: Int
    let onScrub: @MainActor (Int) -> Void

    #if DEBUG
    /// How many times a ruler's body ran; the real-window budget tests count a scrub's.
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        Self.bodyRuns += 1
        #endif
        let mapping = mapping
        let visibleX = visibleX
        return Canvas { context, size in
            let shown = visibleX ?? 0...Double(min(size.width, SuiteSize.timelineRulerSpan))
            let marks = mapping.rulerMarks(
                visibleX: shown, tickSpacing: Double(SuiteSize.timelineTickSpacing),
                labelSpacing: Double(SuiteSize.timelineLabelSpacing),
                digitWidth: Double(SuiteSize.timelineLabelDigit)
            )
            let labels = Set(marks.labels)
            var ticks = Path()
            for frame in Set(marks.ticks).union(labels) {
                let x = tickX(mapping, frame)
                ticks.move(to: CGPoint(x: x, y: size.height * (labels.contains(frame) ? 0.4 : 0.7)))
                ticks.addLine(to: CGPoint(x: x, y: size.height))
            }
            // A label past the strip's trailing edge ends at its tick instead (#61).
            let placed = mapping.rulerLabels(
                marks.labels, digitWidth: Double(SuiteSize.timelineLabelDigit),
                padding: Double(SuiteSpacing.xxs), trailingRoom: Double(SuiteSpacing.xl - timelineInset)
            )
            for placement in placed {
                let x = tickX(mapping, placement.frame)
                let label = Text("\(placement.frame)").font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
                if placement.endsAtTick {
                    context.draw(label, at: CGPoint(x: x - SuiteSpacing.xxs, y: 0), anchor: .topTrailing)
                } else {
                    context.draw(label, at: CGPoint(x: x + SuiteSpacing.xxs, y: 0), anchor: .topLeading)
                }
            }
            ticks.move(to: CGPoint(x: 0, y: size.height))
            ticks.addLine(to: CGPoint(x: size.width, y: size.height))
            context.stroke(ticks, with: .color(SuiteColor.separator), lineWidth: 1)
        }
        .frame(height: SuiteSize.timelineRuler)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            onScrub(mapping.frame(atX: Double(drag.location.x - timelineInset)))
        })
        .accessibilityElement()
        .accessibilityLabel("Frame Ruler")
        .accessibilityValue("Frame \(mapping.clamp(playhead))")
        .accessibilityAdjustableAction { direction in
            let frame = mapping.clamp(playhead)
            switch direction {
            case .increment: onScrub(frame < mapping.duration ? frame + 1 : frame)
            case .decrement: onScrub(frame > 0 ? frame - 1 : frame)
            @unknown default: break
            }
        }
    }
}
