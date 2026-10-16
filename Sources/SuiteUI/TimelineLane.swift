// TimelineLane.swift: one track's lane in TimelineStrip, drawn with Canvas:
// spans as rounded bars, keyframes as diamonds, a separator rule along the
// bottom. Equatable over its values and holding no closure, so the strip's
// `.equatable()` skips a lane whose track and mapping didn't change. The strip
// attaches pointer handling (TimelineLaneInput) outside the lane; accessibility
// is in TimelineLaneAccess.
import SwiftUI

struct TimelineLane<ID: Hashable & Sendable>: View {
    let track: TimelineTrack<ID>
    let mapping: FrameMapping

    #if DEBUG
    /// How many times a lane's body ran, over every ID type; the real-window
    /// budget tests count a scrub's.
    static var bodyRuns: Int {
        get { timelineLaneBodyRuns }
        set { timelineLaneBodyRuns = newValue }
    }
    #endif

    var body: some View {
        #if DEBUG
        Self.bodyRuns += 1
        #endif
        let track = track
        let mapping = mapping
        return Canvas { context, size in
            let mid = size.height / 2
            let barColor = SuiteColor.accent.opacity(track.isSelected ? 0.6 : 0.35)
            for span in track.spans {
                let start = tickX(mapping, span.lowerBound)
                let width = max(tickX(mapping, span.upperBound) - start, SuiteSize.timelineKeyframe)
                let bar = CGRect(x: start, y: mid - SuiteSpacing.m / 2, width: width, height: SuiteSpacing.m)
                context.fill(Path(roundedRect: bar, cornerRadius: SuiteRadius.small), with: .color(barColor))
            }
            let half = SuiteSize.timelineKeyframe / 2
            var diamonds = Path()
            for frame in track.keyframes {
                let x = tickX(mapping, frame)
                diamonds.move(to: CGPoint(x: x, y: mid - half))
                diamonds.addLine(to: CGPoint(x: x + half, y: mid))
                diamonds.addLine(to: CGPoint(x: x, y: mid + half))
                diamonds.addLine(to: CGPoint(x: x - half, y: mid))
                diamonds.closeSubpath()
            }
            context.fill(diamonds, with: .color(track.isSelected ? SuiteColor.accent : SuiteColor.secondaryText))
            var rule = Path()
            rule.move(to: CGPoint(x: 0, y: size.height))
            rule.addLine(to: CGPoint(x: size.width, y: size.height))
            context.stroke(rule, with: .color(SuiteColor.separator), lineWidth: 1)
        }
        .frame(height: SuiteSize.timelineLane)
        .background(track.isSelected ? SuiteColor.accent.opacity(0.08) : Color.clear, ignoresSafeAreaEdges: [])
        .modifier(TimelineLaneAccess(track: track))
    }
}

extension TimelineLane: Equatable {
    /// Compares the values a lane draws.
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.track == rhs.track && lhs.mapping == rhs.mapping
    }
}

#if DEBUG
/// TimelineLane.bodyRuns' count: a generic type can't hold a static stored property.
@MainActor private var timelineLaneBodyRuns = 0
#endif
