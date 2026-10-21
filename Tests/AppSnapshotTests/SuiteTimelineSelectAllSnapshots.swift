// SuiteTimelineSelectAllSnapshots.swift: TSA-2's screen (timeline-select-all
// packet, Screens and states). The gallery's `timeline` fixture after Select
// All Keys: every key on Ball, Shadow and Badge picked, Ball selected, the
// strip built with onSelectAllKeys (suiteui-timeline-all-picked-{light,dark}.png).
// Snapshot rendering makes the strip unfocusable, so the focus ring is not in
// these PNGs; the journey's `timeline-all-picked` shot shows it. macOS only.
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteTimelineSelectAllSnapshots {
    @Test func allPicked() throws {
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(AllPickedSample(), name: "suiteui-timeline-all-picked-\(suffix)", scheme: scheme)
        }
    }
}

/// The `timeline` page's tracks with every key picked.
private struct AllPickedSample: View {
    private let fixture = GalleryTimelineFixture.short

    private var tracks: [TimelineTrack<String>] {
        fixture.order.map { id in
            let keys = fixture.keys[id] ?? []
            return TimelineTrack(
                id: id, name: fixture.names[id] ?? id, keys: keys, spans: fixture.spans[id] ?? [],
                pickedFrames: Set(keys.map(\.frame)), isSelected: id == fixture.selected)
        }
    }

    var body: some View {
        TimelineStrip(
            tracks: tracks, duration: fixture.duration, frameWidth: fixture.frameWidth, playhead: fixture.playhead,
            onSelectAllKeys: {})
            .background(SuiteColor.surface, in: RoundedRectangle(cornerRadius: SuiteRadius.medium))
            .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.medium))
            .padding(SuiteSpacing.xxl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
