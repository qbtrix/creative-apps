// SampleFilesTests.swift: every file SampleCatalog.samples names is shipped
// in Bundle/Samples/, non-empty, with an extension its SuiteTypeRegistry type
// lists (onboarding packet OB-11). A row whose fixture export issue is still
// open is disabled naming that issue; when the export lands and is copied in,
// its row is turned on. Files are read by path from #filePath.
import Foundation
import Testing
import SuiteModel

@Suite struct SampleFilesTests {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    /// One row per sample: its file and the fixture export issue that fills it.
    static let rows: [(fileName: String, issue: Int)] = [
        ("Bounce.flare", 837), ("Cards.design", 836), ("beach.ora", 838), ("Sunset.png", 838), ("Intro.halo", 839),
    ]

    /// The catalog's sample is under Bundle/Samples/, non-empty, and its extension matches its type.
    static func check(_ fileName: String) throws {
        let sample = try #require(SampleCatalog.samples.first { $0.fileName == fileName })
        let url = root.appendingPathComponent("Bundle/Samples").appendingPathComponent(sample.fileName)
        #expect(FileManager.default.fileExists(atPath: url.path), "missing Bundle/Samples/\(sample.fileName)")
        let data = try Data(contentsOf: url)
        #expect(!data.isEmpty, "Bundle/Samples/\(sample.fileName) is empty")
        let type = try #require(SuiteTypeRegistry.standard.type(sample.type))
        #expect(type.extensions.contains(url.pathExtension.lowercased()))
    }

    @Test func everySampleHasARow() {
        #expect(Set(Self.rows.map(\.fileName)) == Set(SampleCatalog.samples.map(\.fileName)))
        #expect(Self.rows.count == SampleCatalog.samples.count)
    }

    @Test(.disabled("waits on #837")) func bounceFlare() throws { try Self.check("Bounce.flare") }
    @Test(.disabled("waits on #836")) func cardsDesign() throws { try Self.check("Cards.design") }
    @Test(.disabled("waits on #838")) func beachOra() throws { try Self.check("beach.ora") }
    @Test(.disabled("waits on #838")) func sunsetPng() throws { try Self.check("Sunset.png") }
    @Test(.disabled("waits on #839")) func introHalo() throws { try Self.check("Intro.halo") }
}
