// LibraryLoupeSnapshots.swift: Library's browser in loupe mode on the shoot
// fixture's IMG_0003, a portrait 4000 × 6000 photo drawn on CanvasViewport
// at its own size, in four states, Light and Dark: its full render fitted
// (`library-loupe-fit`), the grid-size preview scaled up
// (`library-loupe-preview`), the full render at 100% (`library-loupe-100`),
// and a failed render with no picture yet: the placeholder with the photo's
// name and size (`library-loupe-placeholder`). The pan is CanvasViewport's
// own scroll state, which J3 step 4 drives. macOS only.
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryLoupeSnapshots {
    /// The shoot sorted by name with IMG_0003 open in the loupe.
    private func shootOnThird() throws -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.setSort(.name)
        let order = catalog.sortedItems.map(\.id)
        try #require(order.count == 24)
        catalog.open(order[2])
        #expect(catalog.loupePosition == "3 of 24")
        return catalog
    }

    /// `catalog` with the loupe photo's sample picture at `longSide` shown as `quality`.
    private func showing(_ quality: RenderQuality, longSide: Int, in catalog: LibraryCatalog) throws -> LibraryCatalog {
        var catalog = catalog
        let request = try #require(catalog.loupeRequest(longSide: longSide, quality: quality))
        let image = try #require(SampleImage.image(for: request.photo, longSide: longSide))
        catalog.showLoupeRender(RenderedPhoto(image: image, histogram: .empty, quality: quality), token: request.token)
        return catalog
    }

    private func shoot(_ catalog: LibraryCatalog, _ state: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryBrowser(model: catalog),
                name: "library-loupe-\(state)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func fit() throws {
        let catalog = try showing(.full, longSide: 1024, in: try shootOnThird())
        #expect(catalog.loupeValue?.hasPrefix("full 683×1024") == true)
        try shoot(catalog, "fit")
    }

    @Test func preview() throws {
        let catalog = try showing(.preview, longSide: 256, in: try shootOnThird())
        #expect(catalog.loupeValue?.hasPrefix("preview") == true)
        try shoot(catalog, "preview")
    }

    @Test func actualSize() throws {
        var catalog = try showing(.full, longSide: 1024, in: try shootOnThird())
        catalog.zoomLoupe(.actual)
        #expect(catalog.loupeValue?.contains("100%") == true)
        try shoot(catalog, "100")
    }

    @Test func placeholder() throws {
        var catalog = try shootOnThird()
        catalog.failLoupeRender(.renderFailed("the decoder gave up"), token: catalog.loupeRenderToken)
        #expect(catalog.loupeRender == nil)
        #expect(catalog.loupeHelp == "Couldn't render this photo: the decoder gave up.")
        #expect(catalog.loupePlaceholder == "IMG_0003  ·  4000 × 6000")
        try shoot(catalog, "placeholder")
    }
}
