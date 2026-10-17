// GalleryRenderingPane.swift: the gallery's `settings-rendering` page
// (canvas-host feature). CH-2 declared it; CH-4 fills it with the Rendering
// menu as a pull-down over the fake preference, and CH-9 moves it to the live
// `RenderingPreference`, in this file only.
import SwiftUI

enum GalleryRenderingPane {
    static let name = "settings-rendering"

    @MainActor static let pages: GalleryPages = [name: { AnyView(RenderingPanePage()) }]
}

/// The Rendering pull-down on the fake preference: Automatic, GPU (Metal) and
/// CPU with the current one checked, and the status line under them.
struct RenderingPanePage: View {
    @State private var model = RenderingMenuModel()

    var body: some View {
        RenderingPullDown(model: model)
            .padding(SuiteSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
