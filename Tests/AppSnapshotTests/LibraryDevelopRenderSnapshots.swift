// LibraryDevelopRenderSnapshots.swift: `library-develop-render` (develop
// DV-13), Light and Dark. The shoot fixture sorted by name with IMG_0001 in
// the loupe at Exposure +1, rendered through the live path: LiveLoupeImaging
// over LiveDevelop (CoreRaster) decodes the fake decoder's gradient, develops it and
// takes its histogram. The loupe shows that picture and the Develop tab beside
// it reads Exposure +1.00 EV and the rendered histogram's mean; on the live
// develop service Vibrance and Saturation show disabled with their reason.
// macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryDevelopRenderSnapshots {
    /// The shoot by name on the live develop and loupe services, IMG_0001 open in the loupe.
    private func shootOnFirst() throws -> LibraryCatalog {
        var catalog = LibraryCatalog()
        let shoot = LibraryFixtures.photos(named: "shoot")
        catalog.load(shoot)
        catalog.services.isPreview = false
        catalog.services.develop = LiveDevelop()
        // The shoot's photos have paths, so the loupe decodes them: the fake decoder draws each one's gradient.
        catalog.services.loupe = LiveLoupeImaging(decoder: FakeDecoder(photos: shoot), develop: LiveDevelop())
        catalog.setSort(.name)
        let first = try #require(catalog.sortedItems.first)
        #expect(first.name == "IMG_0001")
        catalog.select([first.id])
        catalog.open(first.id)
        try #require(catalog.developTargets == [first.id])
        return catalog
    }

    /// `catalog`'s loupe photo rendered by its own (live) loupe service at a long side of 1024.
    private func render(_ catalog: inout LibraryCatalog) async throws -> RenderedPhoto {
        // `loupeRequest` is mutating, so it runs before `#require`, which can't call one.
        let asked = catalog.loupeRequest(longSide: 1024, quality: .full)
        let request = try #require(asked)
        let rendered = try await catalog.services.loupe.render(
            request.photo, settings: request.settings, longSide: request.longSide, quality: .full)
        catalog.showLoupeRender(rendered, token: request.token)
        return rendered
    }

    /// The readout's number: "mean 0.4213" is 0.4213.
    private func mean(_ catalog: LibraryCatalog) -> Double {
        Double(catalog.histogramValue.split(separator: " ").last ?? "") ?? .nan
    }

    @Test func liveRender() async throws {
        var catalog = try shootOnFirst()
        let neutral = try await render(&catalog)
        let neutralMean = mean(catalog)
        catalog.setDevelop(.exposure, to: 1, coalesceKey: nil)
        #expect(catalog.developValue(.exposure) == .value(1))
        #expect(catalog.sliderHelp(.vibrance) == LiveDevelop.waiting[.vibrance])
        let developed = try await render(&catalog)
        #expect(developed.image.size == neutral.image.size)
        #expect(developed.image.checksum != neutral.image.checksum, "Exposure +1 didn't change the live render")
        #expect(catalog.loupeRender == developed)
        #expect(mean(catalog) > neutralMean, "the histogram's mean didn't rise: \(catalog.histogramValue)")
        #expect(catalog.developError == nil)
        try draw(catalog)
    }

    /// A window's menu whose develop edits can run (each does nothing here), so the rows show enabled.
    private func menu() -> LibraryMenu {
        let set: @MainActor (DevelopSlider, Double) -> Void = { (_: DevelopSlider, _: Double) -> Void in }
        let setCurve: @MainActor ([DevelopCurvePoint]) -> Void = { (_: [DevelopCurvePoint]) -> Void in }
        var develop = LibraryMenu.Develop()
        develop.set = set
        develop.setCurve = setCurve
        var menu = LibraryMenu()
        menu.photo.develop = develop
        return menu
    }

    /// The loupe on the left, the Develop tab on the panel at the inspector's ideal width on the right.
    private func draw(_ catalog: LibraryCatalog) throws {
        let menu = menu()
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HStack(alignment: .top, spacing: 0) {
                    LibraryBrowser(model: catalog, menu: menu)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    DevelopInspector(model: catalog, menu: menu, cropDraft: nil)
                        .frame(width: SuiteSize.inspectorWidth.ideal, alignment: .topLeading)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(SuiteColor.panel)
                }
                .frame(width: 1440, height: 900),
                name: "library-develop-render-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
