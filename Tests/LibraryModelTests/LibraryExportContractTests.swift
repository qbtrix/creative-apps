// LibraryExportContractTests.swift: EX-1, the export contract: options, the
// final unique-name rule, the fake on it, and the live exporter (EX-2)
// and the catalog's states (EX-3); cancel and retry refuse until EX-13.
import Foundation
import Testing

@testable import LibraryModel

@Suite struct LibraryExportContractTests {
    @Test func optionsKeepTheirClampsAndDefaults() {
        let options = ExportOptions(longEdge: 99999, quality: -5, folder: "/out")
        #expect(options.longEdge == 16384 && options.quality == 0)
        #expect(options.format == .jpeg && options.naming == .original && options.sidecar == false)
        #expect(ExportOptions(longEdge: 1, quality: 120, folder: "/out").longEdge == 16)
        #expect(ExportOptions(folder: "/out").quality == 85)
    }

    @Test func optionsRoundTripThroughJSON() throws {
        let options = ExportOptions(longEdge: nil, quality: 70, folder: "/out", format: .png,
                                    naming: ExportNaming(template: "{name}-{n}"), sidecar: true)
        let data = try JSONEncoder().encode(options)
        #expect(try JSONDecoder().decode(ExportOptions.self, from: data) == options)
        let old = Data(#"{"longEdge":99999,"quality":85,"folder":"/out"}"#.utf8)
        #expect(try JSONDecoder().decode(ExportOptions.self, from: old) == ExportOptions(longEdge: 16384, folder: "/out"))
    }

    @Test func uniqueNamesNeverCollide() {
        #expect(ExportNames.unique(stems: ["IMG_0001", "IMG_0001"], format: .jpeg, sidecar: false, existing: ["IMG_0001.jpg"]) == ["IMG_0001 2.jpg", "IMG_0001 3.jpg"])
        #expect(ExportNames.unique(stems: ["IMG_0001"], format: .jpeg, sidecar: false, existing: []) == ["IMG_0001.jpg"])
        #expect(ExportNames.unique(stems: ["a", "b"], format: .png, sidecar: false, existing: ["A.PNG"]) == ["a 2.png", "b.png"])
    }

    @Test func sidecarNameMustBeFreeToo() {
        #expect(ExportNames.unique(stems: ["IMG_0001"], format: .jpeg, sidecar: true, existing: ["IMG_0001.xmp"]) == ["IMG_0001 2.jpg"])
        #expect(ExportNames.unique(stems: ["IMG_0001"], format: .jpeg, sidecar: false, existing: ["IMG_0001.xmp"]) == ["IMG_0001.jpg"])
        #expect(ExportSidecar.fileName(for: "IMG_0001 2.jpg") == "IMG_0001 2.xmp")
        #expect(ExportSidecar.fileName(for: "a.b.tif") == "a.b.xmp")
    }

    @Test func slotsSayWhyTheyCantActYet() {
        #expect(ExportFormat.allCases.map(\.fileExtension) == ["jpg", "png", "tif", "heic"])
        #expect(ExportFormat.jpeg.help(writable: [.jpeg]) == nil)
        #expect(ExportFormat.forFileName("a.JPG") == .jpeg)
        #expect(ExportNaming.original.help == nil && ExportNaming(template: "{n}").help != nil)
        #expect(ExportPresets.unavailable == nil)
        let preset = ExportPreset(name: "Web", options: ExportOptions(longEdge: 1024, quality: 80, folder: "/a"))
        #expect(preset.applied(to: ExportOptions(folder: "/b")) == ExportOptions(longEdge: 1024, quality: 80, folder: "/b"))
        #expect(ExportPresets.decode(ExportPresets.encode(ExportPresetFile(presets: [preset]))) == ExportPresetFile(presets: ExportPresets.builtIns + [preset]))
    }

    @Test func fakeExporterPlansOnTheSharedRule() {
        let photos = Array(LibraryFixtures.photos(named: "shoot").prefix(2))
        let existing: Set<String> = ["IMG_0001.jpg", "IMG_0002.xmp"]
        for sidecar in [false, true] {
            let options = ExportOptions(folder: "/out", sidecar: sidecar)
            let plan = FakeExporter().plan(photos + photos, options: options, existingNames: existing)
            let rule = ExportNames.unique(stems: (photos + photos).map(\.name), format: .jpeg, sidecar: sidecar,
                                          existing: existing)
            #expect(plan.items.map(\.fileName) == rule)
        }
    }

    @Test func liveExporterIsConnectedAndOnlyCancelAndRetryRefuse() async throws {
        var catalog = LibraryCatalog(services: .live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore()))
        let photos = LibraryFixtures.photos(named: "shoot")
        catalog.load(photos)
        catalog.select([photos[0].id])
        // EX-2 connects the exporter (nil reason); EX-3 fills the catalog's export states.
        #expect(LiveExporter.unavailable == nil)
        #expect(catalog.exportHelp == nil && catalog.exportTargets.map(\.id) == [photos[0].id])
        #expect(catalog.beginExport(folder: "/out") == true)
        #expect(catalog.exportPreview?.hasPrefix("\(photos[0].name).jpg · ") == true)
        // Cancel and retry stay stubs until EX-13.
        let before = catalog
        #expect(catalog.cancelExport() == false)
        #expect(catalog.retryExport(options: ExportOptions(folder: "/out"), existingNames: []) == nil)
        #expect(catalog == before)

        let plan = FakeExporter().plan(Array(photos.prefix(2)), options: ExportOptions(folder: "/out"), existingNames: [])
        let writer = FakeJPEGWriter()
        let summary = await ExportRunner.run(plan, photos: [:], exporter: FakeExporter(), writer: writer,
                                             writeSidecar: { _, _, _ in }, progress: { _ in })
        #expect(summary.written.isEmpty && summary.failedIDs == plan.items.map(\.photoID))
        #expect(summary.failures.map(\.reason) == plan.items.map { LibraryError.missingFile($0.photoID).message })
        #expect(await writer.files.isEmpty)
    }
}
