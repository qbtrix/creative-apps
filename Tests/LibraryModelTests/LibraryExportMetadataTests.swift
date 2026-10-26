// LibraryExportMetadataTests.swift: MX-LX, the metadata policy on Library's
// export (packet docs/blueprints/library/features/export-pack.md). LX-1 adds
// `ExportOptions.metadata` and the sidecar's signature; LX-3, which makes the
// sidecar and the exporter follow the policy, enabled the rest. The policy is SuiteKernel's
// `ExportMetadata`, and the dropped tags are `ExportRules.dropped` (rule 20).
import CoreColor
import Foundation
import SuiteKernel
import Testing

@testable import LibraryModel

@Suite struct LibraryExportMetadataOptionsTests {
    @Test func anOldOptionsFileReadsAllButLocation() throws {
        let old = Data(#"{"longEdge":2048,"quality":85,"folder":"/out","sidecar":true}"#.utf8)
        let options = try JSONDecoder().decode(ExportOptions.self, from: old)
        #expect(options.metadata == .noLocation)
        #expect(options == ExportOptions(folder: "/out", sidecar: true))
        #expect(ExportOptions(folder: "/out").metadata == .noLocation)
    }

    @Test func thePolicyRoundTrips() throws {
        for policy in [ExportMetadata.all, .noLocation, .none] {
            let options = ExportOptions(folder: "/out", metadata: policy)
            let data = try JSONEncoder().encode(options)
            #expect(String(data: data, encoding: .utf8)?.contains(#""metadata":"\#(policy.rawValue)""#) == true)
            #expect(try JSONDecoder().decode(ExportOptions.self, from: data) == options)
        }
    }
}

@Suite struct LibraryExportMetadataTests {
    /// IMG_0001: 3 stars, a pick, Red, exposure 0.5.
    func photo() throws -> PhotoItem {
        PhotoItem(id: "/shoot/IMG_0001.jpg", name: "IMG_0001", captureDate: try Date("2026-06-01T10:07:00Z", strategy: .iso8601),
                  color: Color3(0.5, 0.5, 0.5), rating: 3, label: .red, flag: .pick, path: "/shoot/IMG_0001.jpg",
                  pixelSize: PixelSize(width: 6000, height: 4000), develop: DevelopSettings.neutral.setting(.exposure, to: 0.5))
    }

    func packet(_ metadata: ExportMetadata) throws -> String {
        let data = try #require(ExportSidecar.xmp(for: try photo(), metadata: metadata))
        return try #require(String(data: data, encoding: .utf8))
    }

    @Test func sidecarDropsGPS() throws {
        let text = try packet(.noLocation)
        for kept in [#"xmp:Rating="3""#, #"xmp:Label="Red""#, #"library:Flag="pick""#, #"library:Exposure="0.5""#] {
            #expect(text.contains(kept), "\(kept) is missing")
        }
        #expect(!text.contains("exif:GPS"))
        // A located source's tags go, whatever the photo carries.
        let located: [(name: String, value: String)] = [("xmp:Rating", "3"), ("exif:GPSLatitude", "48,51.4N"),
                                                         ("aux:SerialNumber", "123"), ("library:Name", "a")]
        #expect(ExportSidecar.kept(located, metadata: .noLocation).map(\.name) == ["xmp:Rating", "library:Name"])
        #expect(ExportSidecar.kept(located, metadata: .all).map(\.name) == located.map(\.name))
        #expect(try packet(.all) == (try packet(.noLocation)))
    }

    @Test func keepsLibraryFields() throws {
        let text = try packet(.none)
        #expect(!text.contains("xmp:CreateDate"))
        #expect(text.contains(#"xmlns:library="https://github.com/qbtrix/creative-apps/ns/library/1.0/""#))
        for kept in [#"library:Name="IMG_0001""#, #"library:Flag="pick""#, #"library:Exposure="0.5""#] {
            #expect(text.contains(kept), "\(kept) is missing")
        }
        // None drops what ExportRules drops, rating and label included.
        for name in ExportRules.dropped(.none).xmp { #expect(!text.contains(name + "=")) }
        #expect(try packet(.all).contains("xmp:CreateDate"))
    }

    @Test func writerDrops() async throws {
        let item = try photo()
        let exporter = LiveExporter(decoder: FakeDecoder(photos: []), develop: FakeDevelop())
        for policy in [ExportMetadata.all, .noLocation, .none] {
            let plan = exporter.plan([item], options: ExportOptions(longEdge: 1024, folder: "/out", metadata: policy),
                                     existingNames: [])
            let writer = FakeJPEGWriter()
            let summary = await ExportRunner.run(plan, photos: [item.id: item], exporter: FakeExporter(), writer: writer,
                                                 writeSidecar: { _, _, _ in }, progress: { _ in })
            #expect(summary.message == "Exported 1 photo.")
            #expect(await writer.dropped["/out/IMG_0001.jpg"] == ExportRules.dropped(policy).properties)
            #expect(await writer.sources["/out/IMG_0001.jpg"] == "/shoot/IMG_0001.jpg")
        }
        #expect(!ExportRules.dropped(.noLocation).properties.isEmpty)
    }
}
