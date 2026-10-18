// GalleryInspector.swift: the gallery's inspector pages (inspector rows, the
// curve editors and the notes under rows). `inspector` and `curves` start as
// stubs naming the feature that fills them; inspector-controls replaces them
// with real components over each page's own state, in this file only.
// `notes` draws InspectorNote in both kinds, inset like the rows.
import SwiftUI

enum GalleryInspector {
    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(
        ["inspector", "curves"], feature: "inspector-controls"
    ).merging(["notes": { AnyView(GalleryNotesPage()) }]) { first, _ in first }
}

private struct GalleryNotesPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorSection("Layer") {
                InspectorNote("Select a layer to edit its properties.")
                InspectorNote("Unlock Title to change it.", kind: .error, identifier: "suite.gallery.notes.error")
            }
            Spacer()
        }
        .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }
}
