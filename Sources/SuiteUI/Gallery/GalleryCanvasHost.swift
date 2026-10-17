// GalleryCanvasHost.swift: the gallery's `canvas-host` page (canvas-host
// feature). CH-2 declares it as a placeholder calling `CanvasHostPage`; CH-3
// fills that page with the AppKit host on `FakeCanvasContent`, a fake input
// delegate and its log, in this file only.
import SwiftUI

enum GalleryCanvasHost {
    static let name = "canvas-host"

    @MainActor static let pages: GalleryPages = [name: { AnyView(CanvasHostPage()) }]
}

/// The canvas host on the fakes. A placeholder naming the feature until CH-3.
struct CanvasHostPage: View {
    var body: some View {
        EmptyStateView(
            SuiteGallery.stubTitle(page: GalleryCanvasHost.name, feature: "canvas-host"),
            systemImage: "square.dashed", message: "This page is a placeholder until then.")
    }
}
