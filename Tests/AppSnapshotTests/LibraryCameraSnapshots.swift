// LibraryCameraSnapshots.swift: the Info tab's Camera section (metadata-more MD-8) on
// the cameras fixture by name, at UTC: IMG_0001 (`library-camera`), IMG_0001…6
// (`library-camera-mixed`) and IMG_0024 without Exif (`library-camera-none`).
// Written before its view (contract rule 13, MD-5); MD-8 turned them on.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

@MainActor
@Suite struct LibraryCameraSnapshots {
    private func cameras(selecting numbers: [Int]) throws -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "cameras"))
        catalog.services.isPreview = false
        catalog.setSort(.name)
        try #require(catalog.order.count == 24)
        let names = Set(numbers.map { "IMG_" + LibraryFixtures.padded($0, to: 4) })
        catalog.select(Set(catalog.sortedItems.filter { names.contains($0.name) }.map(\.id)))
        try #require(catalog.selection.count == numbers.count)
        return catalog
    }

    @Test func onePhoto() throws {
        let catalog = try cameras(selecting: [1])
        let rows = catalog.selectedCameraRows
        #expect(rows.map(\.field) == CameraField.allCases)
        #expect(rows.first?.value == .text("Fixture Optics FX-1"))
        try shoot(catalog, "library-camera")
    }

    @Test func severalPhotos() throws {
        let catalog = try cameras(selecting: Array(1...6))
        let rows = catalog.selectedCameraRows
        #expect(rows.first?.value == .text("2 cameras") && rows.contains { $0.value == .text("ISO 100–3200") })
        try shoot(catalog, "library-camera-mixed")
    }

    @Test func noDetails() throws {
        let catalog = try cameras(selecting: [24])
        #expect(catalog.selectedPhotos.map(\.camera) == [CameraDetails.none])
        try shoot(catalog, "library-camera-none")
    }

    private func shoot(_ catalog: LibraryCatalog, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                LibraryInspector(model: catalog, utcOffset: 0)
                    .frame(width: SuiteSize.inspectorWidth.ideal, height: 900, alignment: .topLeading)
                    .background(SuiteColor.panel)
                    .padding(SuiteSpacing.xxl),
                name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
