// GalleryFeedback.swift: the gallery's feedback pages, the notes an app shows
// about work and state rather than content. `busy` draws BusyNote in both
// forms: the spinner on glass (an open or a save) and the bar row (an import).
// `notice` draws InlineNotice in each kind, as a band with and without an
// action, with a disabled close and detail lines, and bare in a padded column.
import SwiftUI

enum GalleryFeedback {
    @MainActor static let pages: GalleryPages = [
        "busy": { AnyView(GalleryBusyPage()) },
        "notice": { AnyView(GalleryNoticePage()) },
    ]
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

struct GalleryNoticePage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            InlineNotice("Imported 26 photos.", kind: .success, identifier: "suite.gallery.notice.success",
                         close: ToolbarAction("Close", systemImage: "xmark"))
            InlineNotice(
                "Imported 26 photos. 1 file couldn't be imported.", kind: .warning, identifier: "suite.gallery.notice.warning",
                close: ToolbarAction("Close", systemImage: "xmark", unavailableHelp: "Closing isn't connected yet."),
                detail: ["notes.txt: not an image file"]
            ) {
                Button("Hide") {}
            }
            InlineNotice("Library couldn't read its catalog. It was set aside as catalog.json.bad.", kind: .error,
                         identifier: "suite.gallery.notice.error") {
                Button("Show in Finder") {}
            }
            InlineNotice("No new photos in Shoot.", kind: .info, identifier: "suite.gallery.notice.info")
            InlineNotice("Cards.design removed from Recents.", kind: .info, systemImage: "trash",
                         identifier: "suite.gallery.notice.bare", band: false) {
                Button("Undo") {}
            }
            .padding(.horizontal, SuiteSpacing.m)
            Spacer()
        }
        .padding(.vertical, SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
