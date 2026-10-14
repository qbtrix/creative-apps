// GalleryCanvas.swift: the gallery's canvas pages (the viewport, rulers and
// canvas marks). Each starts as a stub naming the feature that fills it;
// canvas-marks replaces the stubs with real components over each page's own
// state, and adds its own pages, in this file only.
import SwiftUI

enum GalleryCanvas {
    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(
        ["canvas", "canvas-pt", "marks"], feature: "canvas-marks")
}
