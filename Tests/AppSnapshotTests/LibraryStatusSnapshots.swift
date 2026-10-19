// LibraryStatusSnapshots.swift: the status row under Library's grid and loupe
// (status-and-layout SL-4) on the shoot fixture, live data, Light and Dark:
// the grid with five photos selected (`library-grid-status`), the loupe at
// 100% (`library-status-loupe`; `library-loupe-status` is
// LibraryLoupeSnapshots' fitted shot), and the progress and problem pills:
// an import running, a preview render and a save error
// (`library-status-progress`). Each state is set under `@testable`, as
// LibraryShellSnapshots does. Every pill carries a `library.status.<id>`
// identifier and help, and an empty live catalog draws no row. macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryStatusSnapshots {
    static let ids: Set<String> = ["selection", "cellSize", "zoom", "position", "import", "render", "save", "preview"]

    /// The shoot sorted by name, on live data.
    private func shoot() throws -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.services.isPreview = false
        catalog.setSort(.name)
        try #require(catalog.order.count == 24)
        return catalog
    }

    /// The shoot with IMG_0001 open in the loupe, showing its sample picture as `quality`.
    private func loupe(_ quality: RenderQuality) throws -> LibraryCatalog {
        var catalog = try shoot()
        let first = try #require(catalog.sortedItems.first?.id)
        catalog.open(first)
        let pending = catalog.loupeRequest(longSide: 512, quality: quality)
        let request = try #require(pending)
        let image = try #require(SampleImage.image(for: request.photo, longSide: 512))
        catalog.showLoupeRender(RenderedPhoto(image: image, histogram: .empty, quality: quality), token: request.token)
        return catalog
    }

    /// The row's pills, each named `library.status.<id>` with its help.
    private func pills(_ catalog: LibraryCatalog) throws -> [String] {
        let row = try #require(catalog.statusRow)
        for pill in row.pills {
            #expect(LibraryStatusBar.identifier(pill) == "library.status.\(pill.id)")
            #expect(Self.ids.contains(pill.id), "unknown pill \(pill.id)")
            #expect(!pill.help.isEmpty, "\(pill.id) has no help")
        }
        return row.pills.map(\.id)
    }

    @Test func gridWithFiveSelected() throws {
        var catalog = try shoot()
        catalog.select(Set(catalog.sortedItems.prefix(5).map(\.id)))
        #expect(try pills(catalog) == ["selection", "cellSize"])
        #expect(catalog.statusRow?.size == "24 photos")
        #expect(catalog.statusRow?.pills.first?.text == "5 selected")
        try shoot(catalog, "library-grid-status")
    }

    @Test func loupeAtActualSize() throws {
        var catalog = try loupe(.full)
        catalog.zoomLoupe(.actual)
        #expect(try pills(catalog) == ["position"])
        #expect(catalog.statusRow?.zoom == 1)
        #expect(catalog.statusRow?.pills.first?.text == "1 of 24")
        try shoot(catalog, "library-status-loupe")
    }

    @Test func progressAndProblems() throws {
        var catalog = try loupe(.preview)
        catalog.importState = .running(ImportProgress(done: 2, total: 27))
        catalog.saveError = "The disk is full."
        #expect(try pills(catalog) == ["zoom", "position", "import", "render", "save"])
        let row = try #require(catalog.statusRow)
        #expect(row.pills.map(\.text) == ["Fit", "1 of 24", "Importing 3 of 27", "Preview", "Not saved"])
        #expect(row.pills.last?.style == .warning && row.pills.last?.help == "The disk is full.")
        try shoot(catalog, "library-status-progress")
    }

    /// An empty live catalog has nothing to say: no row, and the bar takes no height.
    @Test func emptyLiveCatalogDrawsNoRow() {
        var empty = LibraryCatalog()
        empty.services.isPreview = false
        #expect(empty.statusRow == nil)
        let height = NSHostingView(rootView: LibraryStatusBar(model: empty)).fittingSize.height
        #expect(height == 0, "the bar is \(height) pt tall on an empty live catalog")
    }

    /// The browser with the bar under it, the way LibraryWindow stacks them.
    private func shoot(_ catalog: LibraryCatalog, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                VStack(spacing: 0) {
                    LibraryBrowser(model: catalog)
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .top)
                        .clipped()
                    LibraryStatusBar(model: catalog, fitScale: 0.14).fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 1440, height: 900),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
