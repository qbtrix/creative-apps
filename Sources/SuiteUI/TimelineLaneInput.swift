// TimelineLaneInput.swift: a TimelineLane's pointer handling. A click within
// one keyframe's width of a diamond calls onSelectKeyframe with that frame
// (FrameMapping.keyframe(nearX:) picks the nearest); a click elsewhere does
// nothing yet.
import SwiftUI

struct TimelineLaneInput<ID: Hashable & Sendable>: ViewModifier {
    let track: TimelineTrack<ID>
    let mapping: FrameMapping
    let onSelectKeyframe: @MainActor (ID, Int) -> Void

    func body(content: Content) -> some View {
        content.onTapGesture { location in
            let x = Double(location.x - timelineInset)
            if let frame = mapping.keyframe(nearX: x, in: track.keyframes, tolerance: Double(SuiteSize.timelineKeyframe)) {
                onSelectKeyframe(track.id, frame)
            }
        }
    }
}
