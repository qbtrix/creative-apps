// GalleryChrome.swift: the gallery's editor-chrome pages (the editor shell,
// its top bar and rail, and the empty state). Each starts as a stub naming
// the feature that fills it; editor-chrome replaces the stubs with real
// components over each page's own state, in this file only.
import SwiftUI

enum GalleryChrome {
    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(
        ["editor", "editor-plain", "empty"], feature: "editor-chrome")
}
