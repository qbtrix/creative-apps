// GalleryRenderingPane.swift: the gallery's `settings-rendering` page
// (canvas-host feature). CH-2 declared it; CH-4 filled it with the Rendering
// menu as a pull-down over the fake preference; CH-9 runs it on the live
// `RenderingPreference` in the suite's shared defaults domain, so a choice
// made here persists across relaunch and reaches every app on that domain.
// The page runs live with or without -SuiteGalleryFakes.
import SwiftUI

enum GalleryRenderingPane {
    static let name = "settings-rendering"
    /// The defaults domain the page's preference lives in.
    static let suiteName = RenderingPreference.suiteName

    @MainActor static let pages: GalleryPages = [name: { AnyView(RenderingPanePage()) }]

    /// The menu model on the live preference in `suiteName`.
    @MainActor static func liveModel(suiteName: String = GalleryRenderingPane.suiteName) -> RenderingMenuModel {
        RenderingMenuModel(preference: RenderingPreference(suiteName: suiteName))
    }
}

/// The Rendering pull-down on the live preference: Automatic, GPU (Metal) and
/// CPU with the current one checked, and the status line under them.
struct RenderingPanePage: View {
    @State private var model: RenderingMenuModel

    init(model: RenderingMenuModel = GalleryRenderingPane.liveModel()) {
        _model = State(initialValue: model)
    }

    var body: some View {
        RenderingPullDown(model: model)
            .padding(SuiteSpacing.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
