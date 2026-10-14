// GalleryGraph.swift: the gallery's node graph pages. Each starts as a stub
// naming the feature that fills it; node-graph replaces the stubs with real
// components over each page's own state, in this file only.
import SwiftUI

enum GalleryGraph {
    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(
        ["graph", "graph-loop"], feature: "node-graph")
}
