// LibraryExportMetadataWriteTests.swift: export-pack LX-4 (packet
// docs/blueprints/library/features/export-pack.md, slice LX-m). `JPEGWriter`
// carries the original's metadata through `services.metadata` minus the
// policy's dropped tags. Today's test runs on SuiteModel's `FakeMetadata`:
// the writer hands the carrier the encoded still, the original's bytes and
// `ExportRules.dropped(policy).properties`, and an unreadable original copies
// nothing. The file tests read the exported JPEG and HEIC back through the
// live carrier's `properties(of:)`: no GPS, serial or maker note under the
// default policy, model, capture date and copyright kept. They wait on XP-7
// (the live `StillMetadata` in the media slot and the sample
// `Tests/RealJobs/fixtures/gps-phone.jpg`; Wire: export-pack:XP-7). macOS only.
#if os(macOS)
import Foundation
import LibraryModel
import SuiteKernel
import SuiteModel
import SuiteShell
import Testing

@testable import LibraryApp

@Suite struct LibraryExportMetadataWriteTests {
    struct FixtureError: Error, CustomStringConvertible { let description: String }

    /// A fresh temp folder.
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "LibraryExportMetadata-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// A 16 × 12 mid-grey picture.
    private func image() throws -> DisplayImage {
        guard let image = DisplayImage(size: PixelSize(width: 16, height: 12), rgba8: [UInt8](repeating: 128, count: 16 * 12 * 4))
        else { throw FixtureError(description: "can't make the picture") }
        return image
    }

    /// The phone photo with GPS, serials, a maker note, model, capture date and copyright (XP-7's sample).
    private var sample: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "RealJobs/fixtures/gps-phone.jpg")
    }

    @Test func theWriterHandsTheCarrierTheOriginalAndTheDroppedTags() async throws {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = Data([0xFF, 0xD8, 0xFF, 0xE1, 0x00, 0x02, 0xFF, 0xD9])
        let source = root.appending(path: "IMG_0001.jpg")
        try original.write(to: source)
        let carrier = FakeMetadata()
        let writer = JPEGWriter(metadata: carrier)
        let dropping = ExportRules.dropped(ExportOptions(folder: root.path).metadata).properties
        try await writer.write(try image(), quality: 90, folder: root.path, fileName: "out.jpg",
                               metadataFrom: source.path, dropping: dropping)
        #expect(carrier.carried.map(\.source) == [original])
        #expect(carrier.carried.map(\.dropping) == [ExportRules.dropped(.noLocation).properties])
        let written = try Data(contentsOf: root.appending(path: "out.jpg"))
        #expect(carrier.carried.map(\.still) == [written])
        #expect(written.prefix(2) == Data([0xFF, 0xD8]))

        try await writer.write(try image(), quality: 90, folder: root.path, fileName: "gone.jpg",
                               metadataFrom: root.appending(path: "missing.jpg").path, dropping: dropping)
        #expect(carrier.carried.count == 1)
        #expect(FileManager.default.fileExists(atPath: root.appending(path: "gone.jpg").path))
    }

    /// The live carrier, as the app gets it (`SuiteServices.metadata`).
    private func live(_ root: URL) -> any MetadataCarrying {
        SuiteServices.live(support: root.path, app: .library, arguments: []).metadata
    }

    /// Writes `fileName` from the sample under `policy` and returns the export's property paths.
    private func exported(_ fileName: String, policy: ExportMetadata) async throws -> Set<String> {
        let root = try folder()
        defer { try? FileManager.default.removeItem(at: root) }
        let carrier = live(root)
        try await JPEGWriter(metadata: carrier).write(
            try image(), quality: 90, folder: root.path, fileName: fileName, metadataFrom: sample.path,
            dropping: ExportRules.dropped(policy).properties)
        return try carrier.properties(of: try Data(contentsOf: root.appending(path: fileName)))
    }

    private func expectNoLocation(_ paths: Set<String>) {
        #expect(!paths.contains { $0.hasPrefix("{GPS}") })
        #expect(!paths.contains { $0.contains("SerialNumber") })
        #expect(!paths.contains { $0.hasPrefix("{Maker") || $0 == "{Exif}.MakerNote" })
        #expect(paths.contains("{TIFF}.Model"))
        #expect(paths.contains("{Exif}.DateTimeOriginal"))
        #expect(paths.contains("{TIFF}.Copyright"))
    }

    @Test(.disabled("waits on XP-7 (StillMetadata, input/gps-phone.jpg)"))
    func theSampleHasWhatTheExportDrops() throws {
        let paths = try live(FileManager.default.temporaryDirectory).properties(of: try Data(contentsOf: sample))
        #expect(paths.contains { $0.hasPrefix("{GPS}") })
        #expect(paths.contains("{TIFF}.Model"))
    }

    @Test(.disabled("waits on XP-7 (StillMetadata, input/gps-phone.jpg)"))
    func theJPEGKeepsAllButLocation() async throws {
        expectNoLocation(try await exported("IMG_0001.jpg", policy: .noLocation))
    }

    @Test(.disabled("waits on XP-7 (StillMetadata, input/gps-phone.jpg)"))
    func theHEICKeepsAllButLocation() async throws {
        guard JPEGWriter.writableFormats().contains(.heic) else { return }
        expectNoLocation(try await exported("IMG_0001.heic", policy: .noLocation))
    }
}
#endif
