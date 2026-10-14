// GalleryInspector.swift: the gallery's inspector pages (inspector rows and
// the curve editors). Each starts as a stub naming the feature that fills it;
// inspector-controls replaces the stubs with real components over each page's
// own state, in this file only.
import SwiftUI

enum GalleryInspector {
    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(
        ["inspector", "curves"], feature: "inspector-controls")
}
