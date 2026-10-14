// GalleryIndex.swift: the gallery's `index` page, a plain List of every other
// page by name. A row opens its page through the gallery's `openGalleryPage`;
// each row is `suite.gallery.index.<page>` in `suite.controls`, so SJ0 can open
// every page from here without listing them.
import SwiftUI

enum GalleryIndex {
    static let name = "index"

    @MainActor static let pages: GalleryPages = [name: { AnyView(GalleryIndexPage()) }]
}

private struct GalleryIndexPage: View {
    @Environment(\.openGalleryPage) private var open

    var body: some View {
        List {
            Section("Gallery Pages") {
                ForEach(SuiteGallery.pageNames.filter { $0 != GalleryIndex.name }, id: \.self) { page in
                    Button(page) { open(page) }
                        .help("Open \(page)")
                        .suiteControl(id: "suite.gallery.index.\(page)", enabled: true, reason: nil)
                }
            }
        }
    }
}
