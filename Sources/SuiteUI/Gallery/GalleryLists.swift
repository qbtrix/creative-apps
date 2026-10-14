// GalleryLists.swift: the gallery's lists-and-layers pages (the window shell,
// the layer list and the thumbnail grid). `window` draws a real SuiteWindow
// through its internal init, which skips the -SuiteGallery check, so the
// page never opens the gallery inside itself. The other pages start as stubs
// naming the feature that fills them; lists-and-layers replaces them with
// real components over each page's own state, in this file only.
import SwiftUI

enum GalleryLists {
    static let feature = "lists-and-layers"

    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(
        ["layers", "layers-300", "grid", "grid-2000"], feature: feature
    ).merging(["window": { AnyView(GalleryWindowPage()) }]) { first, _ in first }
}

/// The `window` page: a SuiteWindow that never recurses into the gallery.
private struct GalleryWindowPage: View {
    var body: some View {
        SuiteWindow(
            galleryPage: nil, title: "Window", sections: [], selection: nil, onSelect: { _ in },
            content: {
                EmptyStateView(
                    SuiteGallery.stubTitle(page: "window", feature: GalleryLists.feature),
                    systemImage: "square.dashed", message: "This page is a placeholder until then.")
            },
            inspector: {
                EmptyStateView("No Selection", systemImage: "square.dashed", message: "Nothing to inspect yet.")
            })
    }
}
