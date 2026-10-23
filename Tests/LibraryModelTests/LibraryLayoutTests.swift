// LibraryLayoutTests.swift: the window's layout math (status-and-layout
// SL-1): the content width between sidebar and inspector, the grid's column
// count and the loupe's fit scale, including degenerate widths.
import Testing
@testable import LibraryModel

@Suite struct LibraryLayoutTests {
    @Test(arguments: [880.0, 1024, 1280, 1440, 1920], [200.0, 240, 360])
    func contentWidthIsTheWindowMinusSidebarAndInspector(window: Double, inspector: Double) {
        var layout = LibraryLayout()
        layout.inspector = inspector
        #expect(layout.contentWidth(window: window) == window - 200 - inspector)
    }

    @Test func contentWidthNeverGoesBelowZero() {
        #expect(LibraryLayout().contentWidth(window: 300) == 0)
        #expect(LibraryLayout().contentWidth(window: 0) == 0)
    }

    @Test func defaultsMatchTheTokens() {
        let layout = LibraryLayout()
        #expect(layout.sidebar == 200 && layout.inspector == 240)
        #expect(layout.gridPadding == 12 && layout.gridSpacing == 12)
        #expect(layout.cellInset == 4 && layout.canvasInset == 64)
    }

    @Test func gridColumnsFollowTheCellPitch() {
        let layout = LibraryLayout()
        #expect(layout.gridColumns(contentWidth: 440, cell: 160) == 2)
        #expect(layout.gridColumns(contentWidth: 584, cell: 160) == 3)
    }

    @Test func theExactFitWidthGetsItsFullColumnCount() {
        // 372 = 2 * 12 padding + 2 * (160 + 2 * 4) cells + one 12 gap.
        #expect(LibraryLayout().gridColumns(contentWidth: 372, cell: 160) == 2)
        #expect(LibraryLayout().gridColumns(contentWidth: 371, cell: 160) == 1)
    }

    @Test(arguments: [0.0, -50, .nan, .infinity, -.infinity])
    func aDegenerateWidthGetsOneColumn(width: Double) {
        #expect(LibraryLayout().gridColumns(contentWidth: width, cell: 160) == 1)
    }

    @Test func aDegenerateCellGetsOneColumn() {
        let layout = LibraryLayout()
        #expect(layout.gridColumns(contentWidth: 800, cell: .nan) == 1)
        #expect(layout.gridColumns(contentWidth: 800, cell: .infinity) == 1)
        var flat = layout
        flat.cellInset = 0
        flat.gridSpacing = 0
        #expect(flat.gridColumns(contentWidth: 800, cell: 0) == 1)
    }

    @Test func gridColumnsNeverExceedTenThousand() {
        let layout = LibraryLayout()
        #expect(layout.gridColumns(contentWidth: 1e300, cell: 1) == 10_000)
        #expect(layout.gridColumns(contentWidth: Double.greatestFiniteMagnitude, cell: 160) == 10_000)
    }

    @Test func theNarrowestWindowShowsAtLeastTwoColumns() {
        let layout = LibraryLayout()
        #expect(layout.gridColumns(contentWidth: layout.contentWidth(window: 880), cell: 160) >= 2)
    }

    @Test func loupeFitLeavesTheCanvasInsetOnTheTighterAxis() {
        let layout = LibraryLayout()
        let viewport = (width: 840.0, height: 700.0)
        #expect(layout.loupeFit(viewport: viewport, photo: PixelSize(width: 6000, height: 4000)) == (840.0 - 128) / 6000)
        #expect(layout.loupeFit(viewport: viewport, photo: PixelSize(width: 4000, height: 6000)) == (700.0 - 128) / 6000)
    }

    @Test func loupeFitIsOneForAZeroSizePhoto() {
        let layout = LibraryLayout()
        let viewport = (width: 840.0, height: 700.0)
        #expect(layout.loupeFit(viewport: viewport, photo: PixelSize(width: 0, height: 0)) == 1)
        #expect(layout.loupeFit(viewport: viewport, photo: PixelSize(width: 6000, height: 0)) == 1)
        #expect(layout.loupeFit(viewport: viewport, photo: PixelSize(width: 0, height: 4000)) == 1)
    }

    @Test func loupeFitNeverGoesNegative() {
        let layout = LibraryLayout()
        #expect(layout.loupeFit(viewport: (width: 100, height: 100), photo: PixelSize(width: 600, height: 400)) == 0)
    }
}
