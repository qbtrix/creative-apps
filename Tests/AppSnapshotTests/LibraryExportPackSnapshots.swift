// LibraryExportPackSnapshots.swift: the export sheet's Metadata row (export-pack
// LX-2), editing with All but location picked, in Light and Dark:
// library-export-metadata. The row's policy is the one the shared ExportPick
// carries. macOS only; LX-5 adds the render budget.
import LibraryModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryExportPackSnapshots {
    @Test func metadata() throws {
        let options = ExportOptions(folder: "/Users/me/Pictures/Export")
        #expect(options.metadata == .noLocation)
        for scheme in [ColorScheme.light, .dark] {
            let sheet = LibraryExportSheet(
                state: .editing(options), count: 3, preview: "IMG_0001.jpg · 2048 × 1365", writable: [.jpeg],
                exportHelp: nil, presets: [], progressDelay: .zero)
            try snapshot(sheet, name: "library-export-metadata-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func metadataRowReadsThePick() {
        #expect(LibraryExportSheet.metadataOptions.map(\.title) == ["All", "All but location", "None"])
        #expect(LibraryExportSheet.metadataOptions.map(\.identifier) == [
            "library.export.metadata.all", "library.export.metadata.noLocation", "library.export.metadata.none",
        ])
        let none = ExportOptions(quality: 70, folder: "/Out", format: .heic, metadata: ExportMetadata.none)
        #expect(LibraryExportSheet.pick(none) == ExportPick(format: "HEIC", quality: 0.7, metadata: ExportMetadata.none))
        #expect(LibraryExportSheet.pick(ExportOptions(folder: "/Out")).metadata == .noLocation)
    }
}
