// SuiteTimelineSnapshots.swift: SuiteUI's TimelineStrip over sample data, in
// Light and Dark: three tracks of keyframes with the second selected, and
// tracks of spans the way Halo draws in and out points. Writes
// suiteui-timeline-{light,dark}.png and suiteui-timeline-spans-{light,dark}.png.
// macOS only.
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteTimelineSnapshots {
    @Test func timeline() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(TimelineSample(tracks: TimelineSample.keyframes), name: "suiteui-timeline-\(suffix)", scheme: scheme)
            try snapshot(TimelineSample(tracks: TimelineSample.spans), name: "suiteui-timeline-spans-\(suffix)", scheme: scheme)
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

    let tracks: [TimelineTrack<String>]

    var body: some View {
        TimelineStrip(tracks: tracks, duration: 120, frameWidth: 10, playhead: 30)
            .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
            .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.medium))
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
