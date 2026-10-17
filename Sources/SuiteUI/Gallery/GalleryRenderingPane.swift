// GalleryRenderingPane.swift: the gallery's `settings-rendering` page
// (canvas-host feature). CH-2 declares it as a placeholder calling
// `RenderingPanePage`; CH-4 fills that page with the Rendering menu as a
// pull-down over the fake preference, and CH-9 moves it to the live
// `RenderingPreference`, in this file only.
import SwiftUI

enum GalleryRenderingPane {
    static let name = "settings-rendering"

    @MainActor static let pages: GalleryPages = [name: { AnyView(RenderingPanePage()) }]
}

/// The Rendering menu and its status line. A placeholder naming the feature until CH-4.
struct RenderingPanePage: View {
    var body: some View {
        EmptyStateView(
            SuiteGallery.stubTitle(page: GalleryRenderingPane.name, feature: "canvas-host"),
            systemImage: "square.dashed", message: "This page is a placeholder until then.")
    }
}
