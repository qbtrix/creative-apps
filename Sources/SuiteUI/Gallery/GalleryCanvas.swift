// GalleryCanvas.swift: the gallery's canvas pages (the viewport, rulers and
// canvas marks). `canvas`, `canvas-pt` and `marks` start as stubs naming the
// feature that fills them; canvas-marks replaces them with real components
// over each page's own state, and adds its own pages, in this file only.
// `probe` places a ProbeElement, the hidden element journeys read values
// from, under a caption naming it (it draws nothing itself).
import SwiftUI

enum GalleryCanvas {
    @MainActor static let pages: GalleryPages = SuiteGallery.stubs(
        ["canvas", "canvas-pt", "marks"], feature: "canvas-marks"
    ).merging(["probe": { AnyView(GalleryProbePage()) }]) { first, _ in first }
}

private struct GalleryProbePage: View {
    var body: some View {
        Text("suite.gallery.probe carries \"Saved\" as its label.")
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.secondaryText)
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background { ProbeElement("suite.gallery.probe", label: "Saved", value: "Saved") }
    }
}
