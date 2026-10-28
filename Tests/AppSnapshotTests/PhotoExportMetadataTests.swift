// PhotoExportMetadataTests.swift: export-pack quality gate #5834 (bug 2).
// Photo's Export keeps the opened file's metadata: the sample phone photo
// (`Tests/RealJobs/fixtures/gps-phone.jpg`: GPS, make, model, capture date,
// copyright) is opened and exported as JPEG through the window's own codec,
// then `PhotoWindow.carryingMetadata` copies the source's tags onto it with
// the live `StillMetadata`, read back through the carrier. No source, or an
// unreadable one, leaves the still as encoded. macOS only.
#if os(macOS)
import Foundation
import PhotoModel
import SuiteModel
import SuiteShell
import Testing

@testable import PhotoApp

@Suite struct PhotoExportMetadataTests {
    private var sample: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "RealJobs/fixtures/gps-phone.jpg")
    }

    /// The sample opened in Photo and exported as JPEG, before any metadata step.
    private func exported() async throws -> Data {
        var workspace = PhotoWorkspace()
        try workspace.open(try Data(contentsOf: sample), name: "gps-phone.jpg", codec: ImageIOCodec())
        return try await workspace.export(as: .jpeg, quality: 0.9, codec: ImageIOCodec())
    }

    @Test func anExportKeepsTheSourcesLocationCameraDateAndCopyright() async throws {
        let carrier = StillMetadata()
        let source = try carrier.properties(of: try Data(contentsOf: sample))
        let wanted: Set<String> = ["{GPS}", "{TIFF}.Make", "{TIFF}.Model", "{Exif}.DateTimeOriginal", "{TIFF}.Copyright"]
        #expect(wanted.isSubset(of: source))
        let still = try await exported()
        #expect(try carrier.properties(of: still).isDisjoint(with: ["{GPS}", "{Exif}.DateTimeOriginal"]))
        let kept = try carrier.properties(of: PhotoWindow.carryingMetadata(still, from: sample))
        #expect(wanted.isSubset(of: kept), "missing \(wanted.subtracting(kept).sorted())")
        #expect(!kept.contains("Orientation") && !kept.contains("{TIFF}.Orientation"))
    }

    @Test func theCarrierGetsTheSourceAndDropsOnlyTheOrientation() async throws {
        let still = try await exported()
        let carrier = FakeMetadata()
        _ = PhotoWindow.carryingMetadata(still, from: sample, carrier: carrier)
        #expect(carrier.carried.map(\.source) == [try Data(contentsOf: sample)])
        #expect(carrier.carried.map(\.dropping) == [["Orientation", "{TIFF}.Orientation"]])
    }

    @Test func noSourceOrAnUnreadableOneLeavesTheStillAsEncoded() async throws {
        let still = try await exported()
        #expect(PhotoWindow.carryingMetadata(still, from: nil) == still)
        let missing = FileManager.default.temporaryDirectory.appending(path: "no-such-\(UUID().uuidString).jpg")
        #expect(PhotoWindow.carryingMetadata(still, from: missing) == still)
    }
}
#endif
