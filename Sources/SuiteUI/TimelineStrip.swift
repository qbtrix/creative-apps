// TimelineStrip.swift: the horizontal timeline Flare and Halo share. A fixed
// left column names the tracks; to its right a horizontal scroll area holds a
// frame ruler and one lane per track, drawn with Canvas. Lanes show keyframes
// as diamonds and spans (Halo's in and out points) as rounded bars. Tracks are
// content, so nothing here is glass. Values in, closures out: dragging on the
// ruler calls onScrub, clicking a diamond onSelectKeyframe, clicking a name
// onSelectTrack. All frame arithmetic lives in FrameMapping, which clamps, so
// a closure only ever gets a frame inside 0...duration. The ruler draws only
// the ticks and labels inside the scrolled-to stretch, so a long duration
// costs no more than a short one. Moving keyframes by drag is not here yet.
import SwiftUI

/// One row of the timeline: its name, keyframe frames and spans of frames.
public struct TimelineTrack<ID: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    public let id: ID
    public let name: String
    public let keyframes: [Int]
    public let spans: [ClosedRange<Int>]
    public let isSelected: Bool

    public init(
        id: ID, name: String, keyframes: [Int] = [], spans: [ClosedRange<Int>] = [], isSelected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.keyframes = keyframes
        self.spans = spans
        self.isSelected = isSelected
    }
}

public struct TimelineStrip<ID: Hashable & Sendable>: View {
    private let tracks: [TimelineTrack<ID>]
    private let mapping: FrameMapping
    private let playhead: Int
    private let onScrub: @MainActor (Int) -> Void
    private let onSelectKeyframe: @MainActor (ID, Int) -> Void
    private let onSelectTrack: @MainActor (ID) -> Void
    @Environment(\.suiteSnapshotRendering) private var snapshot
    /// The stretch of the lanes the scroll view shows, in mapping x; nil until
    /// it first reports.
    @State private var visibleX: ClosedRange<Double>?

    /// `duration` is the last frame and `frameWidth` the points per frame;
    /// `playhead` is the current frame.
    public init(
        tracks: [TimelineTrack<ID>], duration: Int, frameWidth: CGFloat, playhead: Int,
        onScrub: @escaping @MainActor (Int) -> Void = { _ in },
        onSelectKeyframe: @escaping @MainActor (ID, Int) -> Void = { _, _ in },
        onSelectTrack: @escaping @MainActor (ID) -> Void = { _ in }
    ) {
        self.tracks = tracks
        self.mapping = FrameMapping(duration: duration, frameWidth: Double(frameWidth))
        self.playhead = playhead
        self.onScrub = onScrub
        self.onSelectKeyframe = onSelectKeyframe
        self.onSelectTrack = onSelectTrack
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 0) {
            names
            Divider()
            // ImageRenderer can't draw a ScrollView, so snapshots show the
            // lanes clipped at the strip's edge instead.
            if snapshot {
                lanes.frame(maxWidth: .infinity, alignment: .leading).clipped()
            } else {
                ScrollView(.horizontal) { lanes }
                    .onScrollGeometryChange(for: ClosedRange<Double>.self) { geometry in
                        let rect = geometry.visibleRect
                        let low = Double(rect.minX - timelineInset)
                        return low...max(low, Double(rect.maxX - timelineInset))
                    } action: { _, visible in
                        visibleX = visible
                    }
            }
        }
        .frame(height: SuiteSize.timelineRuler + SuiteSize.timelineLane * CGFloat(tracks.count), alignment: .top)
    }

    private var names: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: SuiteSize.timelineRuler)
            ForEach(tracks) { track in
                Button { onSelectTrack(track.id) } label: {
                    Text(track.name)
                        .font(track.isSelected ? SuiteFont.headline : SuiteFont.body)
                        .lineLimit(1)
                        .padding(.horizontal, SuiteSpacing.s)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(height: SuiteSize.timelineLane)
                // `ignoresSafeAreaEdges: []`: a color background ignores every safe-area edge by default,
                // so under a floating sidebar the selected row reached 208 pt left of the strip (#1034).
                .background(track.isSelected ? SuiteColor.accent.opacity(0.15) : Color.clear, ignoresSafeAreaEdges: [])
                .accessibilityAddTraits(track.isSelected ? .isSelected : [])
            }
        }
        .frame(width: SuiteSize.timelineLabelColumn)
    }

    private var lanes: some View {
        VStack(alignment: .leading, spacing: 0) {
            ruler
            ForEach(tracks) { lane($0) }
        }
        .frame(width: CGFloat(mapping.contentWidth) + SuiteSpacing.xl, alignment: .leading)
        .overlay { playheadLine.allowsHitTesting(false) }
    }

    private var ruler: some View {
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

    private func lane(_ track: TimelineTrack<ID>) -> some View {
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
        .contentShape(Rectangle())
        .onTapGesture { location in
            let x = Double(location.x - timelineInset)
            if let frame = mapping.keyframe(nearX: x, in: track.keyframes, tolerance: Double(SuiteSize.timelineKeyframe)) {
                onSelectKeyframe(track.id, frame)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(track.name)
        .accessibilityValue("\(track.keyframes.count) keyframes")
    }

    private var playheadLine: some View {
        let x = tickX(mapping, playhead)
        return Canvas { context, size in
            let line = CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)
            context.fill(Path(line), with: .color(SuiteColor.accent))
        }
    }
}

/// Room before frame 0, so its diamond and label aren't clipped.
private let timelineInset = SuiteSpacing.s

/// The x of a frame's tick inside the lanes.
private func tickX(_ mapping: FrameMapping, _ frame: Int) -> CGFloat {
    timelineInset + CGFloat(mapping.x(forFrame: frame))
}
