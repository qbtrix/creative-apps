// LibraryDevelopSnapshots.swift: Library's Develop tab (develop DV-9) on the
// shoot fixture sorted by name, on the fakes, Light and Dark, with a menu
// whose Develop actions all can run: `library-develop` (IMG_0001 at Exposure
// +0.50 and Contrast 13, its settings copied, so TONE shows its reset and
// Paste names them), `library-develop-mixed` (IMG_0001 … IMG_0003 with only
// the first's Exposure set: Exposure reads "Mixed", and Sync reads "Sync from
// IMG_0001"), `library-develop-error` (the loupe's render failed: the line
// under the histogram), `library-develop-empty` (nothing selected: the
// EmptyStateView) and `library-develop-curve` (DV-10: IMG_0001 with a
// three-point curve and Midtones 1.20, so CURVE and LEVELS show their
// resets). macOS only.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryDevelopSnapshots {
    /// The shoot sorted by name, on live data, with its first `count` photos selected.
    private func shoot(selecting count: Int) throws -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.services.isPreview = false
        catalog.setSort(.name)
        try #require(catalog.order.count == 24)
        catalog.select(Set(catalog.sortedItems.prefix(count).map(\.id)))
        return catalog
    }

    /// A window's menu where every Develop action can run (each does nothing here).
    private func menu(for catalog: LibraryCatalog) -> LibraryMenu {
        // Each action in its own typed local, as LibraryWindow+Develop builds
        // them: one long initializer of untyped closures was more than the
        // type checker could finish.
        let none: LibraryMenu.Action = { () -> Void in }
        let set: @MainActor (DevelopSlider, Double) -> Void = { (_: DevelopSlider, _: Double) -> Void in }
        let setCurve: @MainActor ([DevelopCurvePoint]) -> Void = { (_: [DevelopCurvePoint]) -> Void in }
        let setLevels: @MainActor (DevelopLevels.Field, Double) -> Void = {
            (_: DevelopLevels.Field, _: Double) -> Void in
        }
        let reset: @MainActor (DevelopGroup?) -> Void = { (_: DevelopGroup?) -> Void in }
        let resetSlider: @MainActor (DevelopSlider) -> Void = { (_: DevelopSlider) -> Void in }
        var develop = LibraryMenu.Develop()
        develop.set = set
        develop.setCurve = setCurve
        develop.setLevels = setLevels
        develop.endEdit = none
        develop.reset = reset
        develop.resetSlider = resetSlider
        develop.resetCurve = none
        develop.resetLevels = none
        if catalog.syncSource != nil { develop.sync = none }
        develop.syncTitle = catalog.syncTitle
        if catalog.canShowOriginal { develop.toggleOriginal = none }
        var menu = LibraryMenu()
        if catalog.canPasteSettings { menu.photo.pasteSettings = none }
        menu.photo.develop = develop
        return menu
    }

    @Test func onePhoto() throws {
        var catalog = try shoot(selecting: 1)
        catalog.setDevelop(.exposure, to: 0.5, coalesceKey: nil)
        catalog.setDevelop(.contrast, to: 13, coalesceKey: nil)
        catalog.copySettings()
        #expect(catalog.developHelp == nil)
        #expect(catalog.developValue(.exposure) == .value(0.5))
        #expect(catalog.developValue(.contrast) == .value(13))
        #expect(catalog.developValue(.saturation) == .value(0))
        #expect(catalog.copiedSummary == "Exposure +0.50, Contrast 13")
        #expect(catalog.developError == nil)
        try draw(catalog, "library-develop")
    }

    @Test func severalPhotos() throws {
        var catalog = try shoot(selecting: 1)
        catalog.setDevelop(.exposure, to: 0.5, coalesceKey: nil)
        catalog.select(Set(catalog.sortedItems.prefix(3).map(\.id)))
        #expect(catalog.developTargets.count == 3)
        #expect(catalog.developValue(.exposure) == .mixed)
        #expect(catalog.developValue(.contrast) == .value(0))
        #expect(catalog.syncTitle == "Sync from IMG_0001")
        try draw(catalog, "library-develop-mixed")
    }

    @Test func renderFailed() throws {
        var catalog = try shoot(selecting: 1)
        let id = try #require(catalog.sortedItems.first?.id)
        catalog.open(id)
        catalog.failLoupeRender(.renderFailed("the preview failed on purpose"), token: catalog.loupeRenderToken)
        #expect(catalog.developHelp == nil)
        #expect(catalog.developError == "Couldn't render this photo: the preview failed on purpose.")
        #expect(catalog.histogramValue == "mean 0.0000")
        try draw(catalog, "library-develop-error")
    }

    @Test func nothingSelected() throws {
        let catalog = try shoot(selecting: 0)
        #expect(catalog.developHelp == "Select a photo to develop it.")
        try draw(catalog, "library-develop-empty")
    }

    @Test func curveAndLevels() throws {
        var catalog = try shoot(selecting: 1)
        let points = [DevelopCurvePoint(x: 0, y: 0), DevelopCurvePoint(x: 0.5, y: 0.65), DevelopCurvePoint(x: 1, y: 1)]
        catalog.setCurve(points, coalesceKey: nil)
        catalog.setLevels(.gamma, to: 1.2, coalesceKey: nil)
        let curve = try #require(catalog.developCurve?.shared)
        #expect(curve.points.count == 3)
        #expect(!curve.isIdentity)
        #expect(curve.samples().count == 256)
        let levels = try #require(catalog.developLevels?.shared)
        #expect(levels.value(.gamma) == 1.2)
        #expect(levels.value(.inWhite) == 1)
        #expect(catalog.developValue(.exposure) == .value(0))
        try draw(catalog, "library-develop-curve")
    }

    /// Each LEVELS handle edits its own field and speaks that field's name.
    @Test func levelsHandles() {
        for handle in LevelsHandle.allCases {
            #expect(DevelopInspector.field(handle).rawValue == handle.rawValue)
        }
        #expect(DevelopInspector.field(.gamma) == .gamma && DevelopInspector.field(.outBlack) == .outBlack)
    }

    @Test func identifiers() {
        #expect(DevelopInspector.rowID(.exposure) == "library.develop.exposure")
        #expect(DevelopInspector.rowID(.saturation) == "library.develop.saturation")
        #expect(DevelopInspector.histogramID == "library.develop.histogram")
        #expect(DevelopInspector.errorID == "library.develop.error")
        #expect(DevelopInspector.curveID == "library.develop.curve")
        #expect(DevelopInspector.levelsID(.inBlack) == "library.develop.levels.blackpoint")
        #expect(DevelopInspector.levelsID(.gamma) == "library.develop.levels.midtones")
        #expect(DevelopInspector.levelsID(.outWhite) == "library.develop.levels.outputwhite")
    }

    /// The tab at the inspector's ideal width on the panel, as LibraryInspectorSnapshots draws it.
    private func draw(_ catalog: LibraryCatalog, _ name: String) throws {
        let menu = menu(for: catalog)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DevelopInspector(model: catalog, menu: menu, cropDraft: nil)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
