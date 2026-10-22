// LibraryStatusTextTests.swift: what the status row and the inspector header
// say (status-and-layout SL-2), MJ1 (`testStatusWalk`) on the `shoot`
// fixture, the row's cost on `large`, and the header's facts (SL-5): dates,
// kinds, the capture span and the active photo. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

#if DEBUG
/// Release limits are a tenth of the debug ones (packet Quality tests).
private let scale = 1.0
#else
private let scale = 0.1
#endif

/// The shoot sorted by name; `live` turns the preview services off.
private func shoot(live: Bool = false) -> LibraryCatalog {
    var catalog = LibraryCatalog()
    catalog.services.isPreview = !live
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    catalog.setSort(.name)
    return catalog
}

private let gray = Color3(0.5, 0.5, 0.5)

private func path(_ n: Int) -> String { "/fixture/shoot/IMG_" + LibraryFixtures.padded(n, to: 4) + ".jpg" }

private func texts(_ row: LibraryStatusRow?) -> [String] { row?.pills.map(\.text) ?? [] }

private func pill(_ id: String, _ row: LibraryStatusRow?) -> LibraryStatusPill? { row?.pills.first { $0.id == id } }

@Test func testStatusWalk() throws {
    var catalog = shoot()
    var row = try #require(catalog.statusRow)
    #expect(row.size == "24 photos")
    #expect(row.zoom == nil)
    #expect(texts(row) == ["Thumbnails 160 pt", "Preview data"])
    catalog.select(Set((1...5).map(path)))
    #expect(texts(catalog.statusRow) == ["5 selected", "Thumbnails 160 pt", "Preview data"])
    catalog.open(path(1))
    row = try #require(catalog.statusRow)
    #expect(row.size == "6000 × 4000 px")
    #expect(row.zoom == nil && row.fits)
    #expect(row.shownZoom(fitScale: 0.14) == 0.14)
    #expect(texts(row) == ["Loading", "Preview data"])
    catalog.loupeZoom = .actual
    row = try #require(catalog.statusRow)
    #expect(row.zoom == 1 && !row.fits)
    #expect(row.shownZoom(fitScale: 0.14) == 1)
    catalog.selectCollection("favorites")
    #expect(catalog.statusRow?.size == "0 photos")
    let header = catalog.inspectorHeader(utcOffset: 0)
    #expect(header.title == "Picks")
    #expect(header.facts == [.init(label: "Photos", value: "0")])
}

@Test func emptyCatalogs() {
    var live = LibraryCatalog()
    live.services.isPreview = false
    #expect(live.statusRow == nil)
    let fake = LibraryCatalog()
    #expect(fake.statusRow == LibraryStatusRow(
        zoom: nil, size: "0 photos",
        pills: [.init(id: "preview", text: "Preview data", help: LibraryCatalog.previewDataHelp, style: .warning)]))
    #expect(fake.statusRow?.preview?.help == LibraryCatalog.previewDataHelp)
    #expect(fake.statusRow?.trailing == [])
}

@Test func selectionPillOnlyWithASelection() {
    var catalog = shoot(live: true)
    #expect(pill("selection", catalog.statusRow) == nil)
    #expect(texts(catalog.statusRow) == ["Thumbnails 160 pt"])
    #expect(catalog.statusRow?.preview == nil)
    catalog.select([path(2)])
    #expect(pill("selection", catalog.statusRow)?.text == "1 selected")
    #expect(pill("selection", catalog.statusRow)?.style == .selected)
    #expect(pill("cellSize", catalog.statusRow)?.style == .plain)
}

/// #3130: the cell-size pill names the thumbnails and its help says how to change them.
@Test func cellSizePillNamesTheThumbnails() throws {
    let cell = try #require(pill("cellSize", shoot(live: true).statusRow))
    #expect(cell.text.lowercased().contains("thumbnail"))
    #expect(cell.text.contains("160 pt"))
    #expect(cell.help.contains("View > Larger Thumbnails"))
    #expect(cell.help.contains("Smaller Thumbnails"))
}

/// #3135: at Fit the loupe's zoom pill reads the measured fit scale, never
/// 100%; the grid shows none; Actual Size reads 100% whatever the fit scale.
@Test func shownZoomUsesTheFitScaleAtFit() throws {
    var catalog = shoot(live: true)
    #expect(catalog.statusRow?.shownZoom(fitScale: 0.14) == nil)
    catalog.open(path(1))
    #expect(catalog.statusRow?.shownZoom(fitScale: 0.14) == 0.14)
    #expect(catalog.statusRow?.shownZoom(fitScale: 0.5) == 0.5)
    catalog.loupeZoom = .actual
    #expect(catalog.statusRow?.shownZoom(fitScale: 0.14) == 1)
}

/// #3129: the grid has no zoom, so the row shows no zoom pill at any fit scale.
@Test func gridShowsNoZoom() throws {
    let row = try #require(shoot(live: true).statusRow)
    #expect(row.zoom == nil && !row.fits)
    #expect(row.shownZoom(fitScale: 0.14) == nil)
    #expect(row.shownZoom(fitScale: 1) == nil)
}

/// #3133 and #3137: the loupe shows its zoom once (no "Fit" pill) and leaves
/// its place to the HUD.
@Test func loupeRowRepeatsNothing() throws {
    var catalog = shoot(live: true)
    catalog.open(path(1))
    let row = try #require(catalog.statusRow)
    let place = try #require(catalog.loupePosition)
    #expect(pill("zoom", row) == nil)
    #expect(pill("position", row) == nil)
    #expect(!texts(row).contains(place))
}

@Test func favoritesCountsTheShownPhotos() {
    var catalog = shoot(live: true)
    catalog.select([path(3)])
    catalog.setFlag(.pick)
    catalog.selectCollection("favorites")
    #expect(catalog.statusRow?.size == "1 photo")
    #expect(catalog.inspectorHeader(utcOffset: 0).facts == [.init(label: "Photos", value: "1")])
}

@Test func zoomFollowsTheLoupe() {
    var catalog = shoot(live: true)
    catalog.open(path(1))
    catalog.loupeZoom = .scale(2.5)
    #expect(catalog.statusRow?.zoom == 2.5)
    #expect(catalog.statusRow?.shownZoom(fitScale: 0.14) == 2.5)
    catalog.loupeZoom = .scale(.nan)
    #expect(catalog.statusRow?.zoom == nil)
    #expect(catalog.statusRow?.shownZoom(fitScale: 0.14) == 0.14)
    #expect(pill("zoom", catalog.statusRow) == nil)
    catalog.loupeZoom = .scale(0)
    #expect(catalog.statusRow?.zoom == nil)
}

@Test func positionFollowsOrder() {
    var catalog = LibraryCatalog()
    catalog.services.isPreview = false
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    // By capture date IMG_0024 is first; by name it is last.
    catalog.open(path(24))
    #expect(catalog.loupePosition == "1 of 24")
    catalog.setSort(.name)
    #expect(catalog.loupePosition == "24 of 24")
    #expect(catalog.statusRow?.size == "4000 × 6000 px")
}

@Test func importPill() {
    var catalog = shoot(live: true)
    catalog.importState = .running(ImportProgress(done: 3, total: 27))
    #expect(pill("import", catalog.statusRow)?.text == "Importing 4 of 27")
}

@Test func renderPills() throws {
    var catalog = shoot(live: true)
    catalog.open(path(1))
    let image = try #require(DisplayImage(size: PixelSize(width: 2, height: 2), rgba8: Array(repeating: 9, count: 16)))
    catalog.loupeRender = RenderedPhoto(image: image, histogram: .empty, quality: .preview)
    #expect(pill("render", catalog.statusRow)?.text == "Preview")
    catalog.loupeRender = RenderedPhoto(image: image, histogram: .empty, quality: .full)
    #expect(pill("render", catalog.statusRow) == nil)
    catalog.loupeError = "Couldn't render this photo: bad data."
    let failed = try #require(pill("render", catalog.statusRow))
    #expect(failed.text == "Render failed")
    #expect(failed.style == .error)
    #expect(failed.help == "Couldn't render this photo: bad data.")
    catalog.showGrid()
    #expect(pill("render", catalog.statusRow) == nil)
}

@Test func savePills() throws {
    var catalog = shoot(live: true)
    catalog.catalogState = .newer(version: 9)
    let readOnly = try #require(pill("save", catalog.statusRow))
    #expect(readOnly.text == "Read only")
    #expect(readOnly.style == .warning)
    #expect(readOnly.help == catalog.catalogState.message)
    catalog.saveError = "The disk is full."
    let failed = try #require(pill("save", catalog.statusRow))
    #expect(failed.text == "Not saved")
    #expect(failed.style == .error)
    #expect(failed.help == "The disk is full.")
}

@Test func statusRowWithinBudget() throws {
    var catalog = LibraryCatalog()
    catalog.load(LibraryFixtures.photos(named: "large"))
    #expect(catalog.statusRow?.size == "10000 photos")
    var row: LibraryStatusRow?
    let grid = Budget.measure("status row-grid-10000") { row = catalog.statusRow }
    #expect(row != nil)
    #expect(grid.median <= 1 * scale)
    let middle = try #require(catalog.order.dropFirst(5_000).first)
    catalog.open(middle)
    let loupe = Budget.measure("status row-loupe-10000") { row = catalog.statusRow }
    #expect(row?.fits == true)
    #expect(loupe.median <= 1 * scale)
}

// SL-5: the header's facts.

@Test func headerForOnePhoto() {
    var catalog = shoot()
    catalog.select([path(1)])
    #expect(catalog.inspectorHeader(utcOffset: 0) == LibraryInspectorHeader(title: "IMG_0001", facts: [
        .init(label: "Captured", value: "2026-06-01 10:07"), .init(label: "Size", value: "6000 × 4000"),
        .init(label: "Kind", value: "JPEG"),
    ]))
    #expect(catalog.inspectorHeader(utcOffset: 19_800).facts.first?.value == "2026-06-01 15:37")
}

@Test(arguments: [
    (0.0, "1970-01-01 00:00"), (-60.0, "1969-12-31 23:59"), (1_709_251_140.0, "2024-02-29 23:59"),
])
func headerDates(seconds: Double, text: String) {
    var catalog = LibraryCatalog()
    catalog.load([PhotoItem(name: "A", captureDate: Date(timeIntervalSince1970: seconds), color: gray, path: "/a.jpg")])
    catalog.select(Set(catalog.order))
    #expect(catalog.inspectorHeader(utcOffset: 0).facts.first == .init(label: "Captured", value: text))
}

@Test(arguments: [
    (nil, "Sample"), ("/a.png", "PNG"), ("/a.heif", "HEIC"), ("/a.tiff", "TIFF"), ("/a", "File"),
] as [(String?, String)])
func headerKinds(path: String?, kind: String) {
    var catalog = LibraryCatalog()
    catalog.load([PhotoItem(name: "A", captureDate: Date(timeIntervalSince1970: 0), color: gray, path: path)])
    catalog.select(Set(catalog.order))
    #expect(catalog.inspectorHeader(utcOffset: 0).facts.last == .init(label: "Kind", value: kind))
}

@Test func headerForSeveralPhotos() {
    var catalog = shoot()
    catalog.select(Set((1...5).map(path)))
    #expect(catalog.inspectorHeader(utcOffset: 0) == LibraryInspectorHeader(
        title: "5 Photos",
        facts: [.init(label: "Active", value: "IMG_0001"), .init(label: "Captured", value: "2026-06-01")]))
    let day = 86_400.0
    catalog.load([3, 1, 2].map { n in
        PhotoItem(
            name: "D\(n)", captureDate: Date(timeIntervalSince1970: 1_780_308_000 + Double(n - 1) * day), color: gray,
            path: "/d\(n).jpg")
    })
    catalog.select(Set(catalog.order))
    #expect(catalog.inspectorHeader(utcOffset: 0).facts.last == .init(label: "Captured", value: "2026-06-01 – 2026-06-03"))
}

/// Several selected: the header names the active photo, the one Sync copies
/// from (#3636); one photo needs no such fact.
@Test func headerNamesTheActivePhoto() {
    var catalog = shoot()
    catalog.select([path(4), path(2), path(7)])
    #expect(catalog.syncSource?.name == "IMG_0002")
    #expect(catalog.inspectorHeader(utcOffset: 0).facts.first == .init(label: "Active", value: "IMG_0002"))
    catalog.select([path(4)])
    #expect(!catalog.inspectorHeader(utcOffset: 0).facts.contains { $0.label == "Active" })
}
