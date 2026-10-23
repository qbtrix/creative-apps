// LibrarySidecarSnapshots.swift: the Info tab's Sidecar row (metadata-more MD-18), saved
// (`library-sidecar-saved`), failed (`library-sidecar-failed`) and another app's file
// (`library-sidecar-foreign`). Written first (MD-14); MD-18 passes the status into the inspector.
import AppKit
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp
@testable import LibraryModel

/// Each state's snapshot name and the write failure behind it (nil: written).
private let sidecarStates: [(name: String, failure: String?)] = [
    ("library-sidecar-saved", nil),
    ("library-sidecar-failed", "Not saved: The folder is read-only."),
    ("library-sidecar-foreign", "IMG_0001.xmp was written by another app; Library left it unchanged."),
]

@MainActor
@Suite struct LibrarySidecarSnapshots {
    @Test(.disabled("waits on MD-18"), arguments: sidecarStates)
    func sidecarRow(name: String, failure: String?) throws {
        let id = "/fixture/shoot/IMG_0001.jpg"
        var photos = LibraryFixtures.photos(named: "shoot")
        photos[0].keywords = ["Pier"]
        photos[0].rating = 3
        var catalog = LibraryCatalog()
        catalog.load(photos)
        catalog.services.isPreview = false
        catalog.select([id])
        let written = failure == nil ? [id: SidecarFields(photo: photos[0])] : [:]
        let status = catalog.sidecarStatus(
            for: id, written: written, failures: failure.map { [id: $0] } ?? [:], writing: [])
        #expect(status == failure ?? "Saved to IMG_0001.xmp")
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
