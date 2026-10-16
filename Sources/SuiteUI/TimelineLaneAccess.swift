// TimelineLaneAccess.swift: a TimelineLane's accessibility. The lane is one
// element named for its track whose value counts its keyframes. Kept O(1): no
// per-key children or string building over a range here (swiftui-rules 3).
import SwiftUI

struct TimelineLaneAccess<ID: Hashable & Sendable>: ViewModifier {
    let track: TimelineTrack<ID>

    func body(content: Content) -> some View {
        content
            .accessibilityElement()
            .accessibilityLabel(track.name)
            .accessibilityValue("\(track.keyframes.count) keyframes")
    }
}
