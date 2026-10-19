// LibraryStatusTextTests.swift: what the status row and the inspector header
// say (status-and-layout SL-2), MJ1 (`testStatusWalk`) on the `shoot`
// fixture, and the row's cost on `large`. The header facts tests are SL-5's,
// written here and disabled until it lands. Runs on Linux and macOS.
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
    #expect(texts(row) == ["160 pt", "Preview data"])
    catalog.select(Set((1...5).map(path)))
    #expect(texts(catalog.statusRow) == ["5 selected", "160 pt", "Preview data"])
    catalog.open(path(1))
    row = try #require(catalog.statusRow)
    #expect(row.size == "6000 × 4000 px")
    #expect(row.zoom == nil)
    #expect(texts(row) == ["Fit", "1 of 24", "Loading", "Preview data"])
    catalog.loupeZoom = .actual
    row = try #require(catalog.statusRow)
    #expect(row.zoom == 1)
    #expect(!texts(row).contains("Fit"))
    catalog.selectCollection("favorites")
    #expect(catalog.statusRow?.size == "0 photos")
    let header = catalog.inspectorHeader(utcOffset: 0)
    #expect(header.title == "Favorites")
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
    #expect(texts(catalog.statusRow) == ["160 pt"])
    #expect(catalog.statusRow?.preview == nil)
    catalog.select([path(2)])
    #expect(pill("selection", catalog.statusRow)?.text == "1 selected")
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
    #expect(pill("zoom", catalog.statusRow) == nil)
    catalog.loupeZoom = .scale(.nan)
    #expect(catalog.statusRow?.zoom == nil)
    #expect(pill("zoom", catalog.statusRow)?.text == "Fit")
    catalog.loupeZoom = .scale(0)
    #expect(catalog.statusRow?.zoom == nil)
}

@Test func positionFollowsOrder() {
    var catalog = LibraryCatalog()
    catalog.services.isPreview = false
    catalog.load(LibraryFixtures.photos(named: "shoot"))
    // By capture date IMG_0024 is first; by name it is last.
    catalog.open(path(24))
    #expect(pill("position", catalog.statusRow)?.text == "1 of 24")
    catalog.setSort(.name)
    #expect(pill("position", catalog.statusRow)?.text == "24 of 24")
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
    #expect(failed.style == .warning)
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
    #expect(failed.style == .warning)
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
    #expect(pill("position", row)?.text == "5001 of 10000")
    #expect(loupe.median <= 1 * scale)
}

// SL-5: the header's facts. Enabled by SL-5.

@Test(.disabled("waits on SL-5")) func headerForOnePhoto() {
    var catalog = shoot()
    catalog.select([path(1)])
    #expect(catalog.inspectorHeader(utcOffset: 0) == LibraryInspectorHeader(title: "IMG_0001", facts: [
        .init(label: "Captured", value: "2026-06-01 10:07"), .init(label: "Size", value: "6000 × 4000"),
        .init(label: "Kind", value: "JPEG"),
    ]))
    #expect(catalog.inspectorHeader(utcOffset: 19_800).facts.first?.value == "2026-06-01 15:37")
}

@Test(.disabled("waits on SL-5"), arguments: [
    (0.0, "1970-01-01 00:00"), (-60.0, "1969-12-31 23:59"), (1_709_251_140.0, "2024-02-29 23:59"),
])
func headerDates(seconds: Double, text: String) {
    var catalog = LibraryCatalog()
    catalog.load([PhotoItem(name: "A", captureDate: Date(timeIntervalSince1970: seconds), color: gray, path: "/a.jpg")])
    catalog.select(Set(catalog.order))
    #expect(catalog.inspectorHeader(utcOffset: 0).facts.first == .init(label: "Captured", value: text))
}

@Test(.disabled("waits on SL-5"), arguments: [
    (nil, "Sample"), ("/a.png", "PNG"), ("/a.heif", "HEIC"), ("/a.tiff", "TIFF"), ("/a", "File"),
] as [(String?, String)])
func headerKinds(path: String?, kind: String) {
    var catalog = LibraryCatalog()
    catalog.load([PhotoItem(name: "A", captureDate: Date(timeIntervalSince1970: 0), color: gray, path: path)])
    catalog.select(Set(catalog.order))
    #expect(catalog.inspectorHeader(utcOffset: 0).facts.last == .init(label: "Kind", value: kind))
}

@Test(.disabled("waits on SL-5")) func headerForSeveralPhotos() {
    var catalog = shoot()
    catalog.select(Set((1...5).map(path)))
    #expect(catalog.inspectorHeader(utcOffset: 0) == LibraryInspectorHeader(
        title: "5 Photos", facts: [.init(label: "Captured", value: "2026-06-01")]))
    let day = 86_400.0
    catalog.load([3, 1, 2].map { n in
        PhotoItem(
            name: "D\(n)", captureDate: Date(timeIntervalSince1970: 1_780_308_000 + Double(n - 1) * day), color: gray,
            path: "/d\(n).jpg")
    })
    catalog.select(Set(catalog.order))
    #expect(catalog.inspectorHeader(utcOffset: 0).facts == [.init(label: "Captured", value: "2026-06-01 – 2026-06-03")])
}
