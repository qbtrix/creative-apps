// TimelineRuler.swift: the frame ruler above TimelineStrip's lanes, pinned
// outside both scroll views: its marks (TimelineRulerMarks) are drawn at the
// lanes' width and shifted by the sideways scroll, inside a clipped view the
// visible width, which carries the drag and the fixed accessibility identifier
// `suite.timeline.ruler`. The marks are only the ticks and labels inside the
// scrolled-to stretch (FrameMapping.rulerMarks), so a long duration costs no
// more than a short one, and they never read the playhead, so a scrub never
// redraws them (#1257). A drag anywhere on it scrubs through the playhead's
// TimelineScrubSender, so it sends only changed frames; VoiceOver reads and
// steps the playhead frame. A snapshot offers the marks the strip's width (#219).
import SwiftUI

struct TimelineRuler: View {
    let mapping: FrameMapping
    /// The stretch of the lanes the scroll view shows, in mapping x; nil until
    /// it first reports.
    let visibleX: ClosedRange<Double>?
    let playhead: Int
    let onScrub: @MainActor (Int) -> Void
    @Environment(\.suiteSnapshotRendering) private var snapshot
    @State private var sender = TimelineScrubSender()

    #if DEBUG
    /// How many times the ruler's marks were drawn; the real-window budget tests count a scrub's.
    static var bodyRuns = 0
    #endif

    var body: some View {
        // The content x at the ruler's leading edge.
        let scrollX = snapshot ? 0 : (visibleX?.lowerBound ?? -Double(timelineInset)) + Double(timelineInset)
        return GeometryReader { proxy in
            TimelineRulerMarks(mapping: mapping, visibleX: visibleX).equatable()
                .frame(width: snapshot ? max(proxy.size.width, 0) : CGFloat(mapping.contentWidth) + SuiteSpacing.xl,
                       alignment: .leading)
                .offset(x: -CGFloat(scrollX))
        }
        .frame(height: SuiteSize.timelineRuler)
        .clipped()
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
            let frame = mapping.frame(atX: Double(drag.location.x - timelineInset) + scrollX)
            sender.send(frame, from: playhead, to: onScrub)
        }.onEnded { _ in sender.end() })
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
        .accessibilityIdentifier("suite.timeline.ruler")
    }
}

/// The ruler's ticks and labels: Equatable over the mapping and the visible
/// stretch, so the strip skips it when only the playhead moved.
struct TimelineRulerMarks: View {
    let mapping: FrameMapping
    let visibleX: ClosedRange<Double>?

    var body: some View {
        #if DEBUG
        TimelineRuler.bodyRuns += 1
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
    }
}

extension TimelineRulerMarks: Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.mapping == rhs.mapping && lhs.visibleX == rhs.visibleX
    }
}
