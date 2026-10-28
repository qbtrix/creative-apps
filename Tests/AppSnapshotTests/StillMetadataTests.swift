// StillMetadataTests.swift: export-pack XP-7 on a Mac. StillMetadata, the
// live MetadataCarrying, carries a GPS-tagged phone JPEG's metadata
// (Tests/RealJobs/fixtures/gps-phone.jpg: GPS, body and lens serials, a maker
// note, orientation 6, DateTimeOriginal and Copyright) onto the same picture
// decoded and encoded again, as an export does. With `.noLocation` the GPS,
// the serials and the maker note are gone and orientation, DateTimeOriginal
// and Copyright stay; with `.none` only orientation and the still's own
// colour profile stay. The HEIC cases make their source from the JPEG with
// ImageIO and skip on a Mac that can't write HEIC. Drop paths come from the
// kernel's rule (`ExportRules.dropped`). macOS only.
#if canImport(ImageIO)
import CoreGraphics
import Foundation
import ImageIO
import SuiteKernel
import SuiteModel
import SuiteShell
import Testing

@Suite struct StillMetadataTests {
    static let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../RealJobs/fixtures/gps-phone.jpg").standardizedFileURL

    static func phone() throws -> Data { try Data(contentsOf: fixture) }

    /// The phone JPEG written as HEIC by ImageIO, its metadata inherited; nil when this Mac can't write HEIC.
    static func phoneHEIC() -> Data? {
        guard let jpeg = try? phone(), let source = CGImageSourceCreateWithData(jpeg as CFData, nil) else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, SuiteImageFormat.heic.typeID.rawValue as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImageFromSource(destination, source, 0, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    static var canWriteHEIC: Bool { phoneHEIC() != nil }

    /// `source` decoded and encoded again as `format`, as an export does: the still carries no metadata of its own.
    static func reencoded(_ source: Data, as format: StillFormat) throws -> Data {
        let media = LiveMedia()
        return try media.still(try media.still(source, longestSide: nil), as: format, quality: 0.9)
    }

    /// The top-level EXIF orientation ImageIO reads from `image`.
    static func orientation(_ image: Data) -> Int? {
        guard let source = CGImageSourceCreateWithData(image as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        else { return nil }
        return properties[kCGImagePropertyOrientation] as? Int
    }

    /// What says where the picture was made and with which device.
    static let identifying = ["{GPS}", "{Exif}.BodySerialNumber", "{Exif}.LensSerialNumber", "{ExifAux}.SerialNumber",
                              "{Exif}.MakerNote"]

    static func hasMakerNote(_ paths: Set<String>) -> Bool {
        paths.contains("{Exif}.MakerNote") || paths.contains { $0.hasPrefix("{Maker") }
    }

    /// `source` re-encoded as `format`, then carried under `policy`: the still, and the paths in the result.
    static func carried(_ source: Data, as format: StillFormat, _ policy: ExportMetadata) throws
        -> (still: Set<String>, result: Set<String>, orientation: Int?) {
        let metadata = StillMetadata()
        let still = try reencoded(source, as: format)
        let out = try metadata.carrying(still, from: source, dropping: ExportRules.dropped(policy).properties)
        return (try metadata.properties(of: still), try metadata.properties(of: out), orientation(out))
    }

    static func expectNoLocation(_ source: Data, as format: StillFormat) throws {
        let (_, paths, orientation) = try carried(source, as: format, .noLocation)
        for path in identifying { #expect(!paths.contains(path), "\(path) survives in \(paths.sorted())") }
        #expect(!hasMakerNote(paths), "a maker note survives in \(paths.sorted())")
        for path in ["{TIFF}.Orientation", "{Exif}.DateTimeOriginal", "{TIFF}.Copyright"] {
            #expect(paths.contains(path), "\(path) is lost from \(paths.sorted())")
        }
        #expect(orientation == 6)
    }

    static func expectNone(_ source: Data, as format: StillFormat) throws {
        let (still, paths, orientation) = try carried(source, as: format, .none)
        for path in identifying + ["{Exif}.DateTimeOriginal", "{TIFF}.Copyright", "{TIFF}.Make", "{TIFF}.Model"] {
            #expect(!paths.contains(path), "\(path) survives in \(paths.sorted())")
        }
        #expect(!hasMakerNote(paths), "a maker note survives in \(paths.sorted())")
        #expect(paths.contains("{TIFF}.Orientation") && orientation == 6, "orientation is lost from \(paths.sorted())")
        if still.contains("ProfileName") { #expect(paths.contains("ProfileName"), "the still's profile is lost") }
    }

    @Test func theFixtureCarriesEverythingThePoliciesDrop() throws {
        let paths = try StillMetadata().properties(of: try Self.phone())
        for path in ["{GPS}", "{Exif}.BodySerialNumber", "{Exif}.LensSerialNumber", "{Exif}.DateTimeOriginal",
                     "{TIFF}.Copyright", "{TIFF}.Orientation", "{TIFF}.Make"] {
            #expect(paths.contains(path), "the fixture lacks \(path): \(paths.sorted())")
        }
    }

    @Test func jpegWithoutLocationKeepsDateCopyrightAndOrientation() throws {
        try Self.expectNoLocation(try Self.phone(), as: .jpeg)
    }

    @Test func jpegWithNoneKeepsOnlyOrientationAndProfile() throws {
        try Self.expectNone(try Self.phone(), as: .jpeg)
    }

    @Test(.enabled(if: StillMetadataTests.canWriteHEIC, "this Mac can't write HEIC"))
    func heicWithoutLocationKeepsDateCopyrightAndOrientation() throws {
        try Self.expectNoLocation(try #require(Self.phoneHEIC()), as: .heic)
    }

    @Test(.enabled(if: StillMetadataTests.canWriteHEIC, "this Mac can't write HEIC"))
    func heicWithNoneKeepsOnlyOrientationAndProfile() throws {
        try Self.expectNone(try #require(Self.phoneHEIC()), as: .heic)
    }

    @Test func anUnreadableSourceCopiesNothing() throws {
        let still = try Self.reencoded(try Self.phone(), as: .jpeg)
        #expect(try StillMetadata().carrying(still, from: Data("not an image".utf8), dropping: []) == still)
    }

    @Test func anUnreadableStillThrows() throws {
        #expect(throws: SuiteError.self) {
            try StillMetadata().carrying(Data("not an image".utf8), from: try Self.phone(), dropping: [])
        }
        #expect(throws: SuiteError.self) { try StillMetadata().properties(of: Data()) }
    }
}
#endif
