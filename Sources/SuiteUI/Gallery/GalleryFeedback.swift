// GalleryFeedback.swift: the gallery's feedback pages, the notes an app shows
// about work and state rather than content. `busy` draws BusyNote in both
// forms: the spinner on glass (an open or a save) and the bar row (an import).
import SwiftUI

enum GalleryFeedback {
    @MainActor static let pages: GalleryPages = ["busy": { AnyView(GalleryBusyPage()) }]
}

private struct GalleryBusyPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.l) {
            BusyNote("Importing 3 of 27", identifier: "suite.gallery.busy.bar", fraction: (2, 27))
            BusyNote("Opening Spot…", identifier: "suite.gallery.busy.spinner")
            Spacer()
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
