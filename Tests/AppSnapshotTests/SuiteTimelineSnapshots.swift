// SuiteTimelineSnapshots.swift: SuiteUI's TimelineStrip over sample data.
// `timeline()` writes the review PNGs in Light and Dark: three tracks of
// keyframes with the second selected, tracks of spans the way Halo draws in
// and out points, and a long timeline whose ruler thins its ticks and labels
// to the width (suiteui-timeline-{light,dark}.png,
// suiteui-timeline-spans-{light,dark}.png, suiteui-timeline-long-{light,dark}.png).
// `goldens()` checks TL-6's lanes against Golden/timeline/ in the four
// appearances: suiteui-timeline (beds, linear, eased and hold keys with their
// tweens, picked keys on a selected track), suiteui-timeline-clips (clip
// blocks with keys over them) and suiteui-timeline-hover (the hovered lane's
// rowHover bed and the accent ring round the key under the pointer). The
// baselines come from the CI artifact (TL-9). macOS only.
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteTimelineSnapshots {
    @Test func timeline() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(TimelineSample(tracks: TimelineSample.keyframes), name: "suiteui-timeline-\(suffix)", scheme: scheme)
            try snapshot(TimelineSample(tracks: TimelineSample.spans), name: "suiteui-timeline-spans-\(suffix)", scheme: scheme)
            let long = TimelineSample(tracks: TimelineSample.keyframes, duration: 20_000, frameWidth: 2)
            try snapshot(long, name: "suiteui-timeline-long-\(suffix)", scheme: scheme)
        }
    }

    @Test func goldens() {
        let size = CGSize(width: 720, height: 200)
        for appearance in SnapshotAppearance.allCases {
            assertGolden(TimelineSample(tracks: TimelineSample.shaped), size: size,
                         name: "suiteui-timeline", area: "timeline", appearance: appearance)
            assertGolden(TimelineSample(tracks: TimelineSample.clips), size: size,
                         name: "suiteui-timeline-clips", area: "timeline", appearance: appearance)
            assertGolden(HoveredLanes(), size: size,
                         name: "suiteui-timeline-hover", area: "timeline", appearance: appearance)
        }
    }
}

private struct TimelineSample: View {
    static let keyframes = [
        TimelineTrack(id: "position", name: "Position", keyframes: [0, 12, 24, 48, 72]),
        TimelineTrack(id: "rotation", name: "Rotation", keyframes: [6, 30, 54], isSelected: true),
        TimelineTrack(id: "opacity", name: "Opacity", keyframes: [0, 36, 96]),
    ]
    static let spans = [
        TimelineTrack(id: "title", name: "Title", spans: [0...48]),
        TimelineTrack(id: "logo", name: "Logo", keyframes: [24, 60], spans: [18...90], isSelected: true),
        TimelineTrack(id: "music", name: "Music", spans: [0...30, 40...110]),
    ]
    /// Linear, eased and hold keys; the selected track's keys picked but one.
    static let shaped = [
        TimelineTrack(id: "position", name: "Position", keys: keys([0: .linear, 12: .eased, 40: .hold, 60: .linear])),
        TimelineTrack(
            id: "rotation", name: "Rotation", keys: keys([6: .eased, 30: .eased, 32: .linear, 54: .hold, 70: .linear]),
            pickedFrames: [6, 30, 54], isSelected: true),
        TimelineTrack(id: "opacity", name: "Opacity", keys: keys([0: .hold, 36: .linear, 96: .eased])),
    ]
    /// Clip blocks, one a single frame wide, with keys over them, one picked.
    static let clips = [
        TimelineTrack(id: "title", name: "Title", keys: keys([10: .linear, 40: .eased]), spans: [0...48]),
        TimelineTrack(
            id: "logo", name: "Logo", keys: keys([24: .linear, 60: .hold]), spans: [18...90], pickedFrames: [24],
            isSelected: true),
        TimelineTrack(id: "music", name: "Music", spans: [0...30, 40...40, 50...110]),
    ]

    static func keys(_ shapes: [Int: TimelineKeyShape]) -> [TimelineKey] {
        shapes.keys.sorted().map { TimelineKey(frame: $0, shape: shapes[$0] ?? .linear) }
    }

    let tracks: [TimelineTrack<String>]
    var duration = 120
    var frameWidth: CGFloat = 10

    var body: some View {
        TimelineStrip(tracks: tracks, duration: duration, frameWidth: frameWidth, playhead: 30)
            .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
            .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.medium))
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// Three lanes drawn alone, the middle one hovered with the pointer on its key at frame 30.
private struct HoveredLanes: View {
    var body: some View {
        let mapping = FrameMapping(duration: 120, frameWidth: 10)
        VStack(spacing: 0) {
            ForEach(TimelineSample.shaped) { track in
                TimelineLane(track: track, mapping: mapping)
                    .environment(\.timelineLaneHover, track.id == "rotation" ? TimelineLaneHover(key: 30) : nil)
            }
        }
        .background(SuiteColor.panel, ignoresSafeAreaEdges: [])
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
