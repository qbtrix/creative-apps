// GalleryIndex.swift: the gallery's `index` page, a grid of buttons naming
// every other page. A button opens its page through the gallery's `openGalleryPage`;
// each button is `suite.gallery.index.<page>` in `suite.controls`, so SJ0 can open
// every page from here without listing them.
import SwiftUI

enum GalleryIndex {
    static let name = "index"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryIndexPage()) }]
}

private struct GalleryIndexPage: View {
    @Environment(\.openGalleryPage) private var open

    /// Four columns, so every page fits the 1024 x 768 runner's window with no
    /// scroller: a List of them ran 10 pt past it, and the scroller's track
    /// showed up as an unnamed control in the app audit.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: SuiteSpacing.s, alignment: .leading), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                // SuiteColor.secondaryText: the List's default section header measured 3.95:1.
                Text("Gallery Pages")
                    .font(SuiteFont.sectionCaps)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .accessibilityAddTraits(.isHeader)
                LazyVGrid(columns: columns, alignment: .leading, spacing: SuiteSpacing.s) {
                    ForEach(SuiteGallery.pageNames.filter { $0 != GalleryIndex.name }, id: \.self) { page in
                        Button(page) { open(page) }
                            .help("Open \(page)")
                            .suiteControl(id: "suite.gallery.index.\(page)", enabled: true, reason: nil)
                    }
                }
            }
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
