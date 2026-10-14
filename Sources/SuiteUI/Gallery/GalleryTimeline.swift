// GalleryTimeline.swift: the gallery's timeline pages (the timeline strip and
// its transport). Each starts as a stub naming the feature that fills it;
// timeline replaces the stubs with real components over each page's own
// state, in this file only.
import SwiftUI

enum GalleryTimeline {
    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(
        ["timeline", "timeline-long"], feature: "timeline")
}
