// GalleryChrome.swift: the gallery's editor-chrome pages (the editor shell,
// its top bar and rail, the empty state and the save status). `editor`,
// `editor-plain` and `empty` start as stubs naming the feature that fills
// them; editor-chrome replaces them with real components over each page's own
// state, in this file only. `save-status` draws EditorSaveStatus in its three
// states.
import SwiftUI

enum GalleryChrome {
    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(
        ["editor", "editor-plain", "empty"], feature: "editor-chrome"
    ).merging(["save-status": { AnyView(GallerySaveStatusPage()) }]) { first, _ in first }
}

private struct GallerySaveStatusPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            EditorSaveStatus(.saved, title: "Saved", help: "Every change is saved.", identifier: "suite.gallery.save.saved")
            EditorSaveStatus(.edited, title: "Edited", help: "Save to keep your changes.", identifier: "suite.gallery.save.edited")
            EditorSaveStatus(.notSaved, title: "Not saved", help: "The disk is full.", identifier: "suite.gallery.save.failed")
            Spacer()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
