// LibraryImageIOTests.swift (shared-codecs SC-7; packet docs/blueprints/suiteui/features/shared-codecs.md,
// MJ-SC-library and LJ-SC): Library's import fixtures must scan and decode the same once SC-8 moves
// ImageIODecoder onto `SuiteImageIO`. Each fixture folder scans to the pixel size (after the Exif orientation),
// kind, capture date and camera Exif that Fixtures/library-imageio-expected.json records from the files' own
// bytes; the orientation-6 still decodes upright; RJ-X46's camera pair (added by SC-3) decodes 3024 x 4032
// with its JPEG and HEIC within 3 levels. The tests call the entry points SC-8 keeps, `ImageIODecoder`'s
// `scan(folder:)` and `decode(path:maxLongSide:)`. Written first, disabled until SC-8. macOS only.
#if os(macOS)
import Foundation
import LibraryModel
import Testing

@testable import LibraryApp

@Suite struct LibraryImageIOTests {
    private let decoder = ImageIODecoder()

    /// Fixtures/library-imageio-expected.json.
    struct Expected: Decodable {
        struct File: Decodable {
            let name: String
            let kind: String
            let stored: [Int]
            let orientation: Int
            let pixelSize: [Int]
            let dateTimeOriginal: String?
            let make: String?
            let model: String?
        }
        struct Folder: Decodable {
            let folder: String
            let files: [File]
        }
        struct Corners: Decodable {
            let topLeft: [Int], topRight: [Int], bottomLeft: [Int], bottomRight: [Int]
        }
        struct Upright: Decodable {
            let path: String
            let pixelSize: [Int]
            let corners: Corners
        }
        struct CameraPair: Decodable {
            let files: [String]
            let stored: [Int]
            let pixelSize: [Int]
            let pairTolerance: Int
        }
        let folders: [Folder]
        let upright: [Upright]
        let rjX46: CameraPair
    }

    private func expected() throws -> Expected {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/library-imageio-expected.json")
        return try JSONDecoder().decode(Expected.self, from: Data(contentsOf: url))
    }

    /// `pair` as a PixelSize; nil unless it holds exactly a width and a height.
    private func size(_ pair: [Int]) -> PixelSize? {
        pair.count == 2 ? PixelSize(width: pair[0], height: pair[1]) : nil
    }

    /// The RGBA bytes of pixel (x, y), top row first; empty when outside the image.
    private func pixel(_ image: DisplayImage, _ x: Int, _ y: Int) -> [Int] {
        let start = (y * image.size.width + x) * 4
        guard x >= 0, y >= 0, x < image.size.width, start >= 0, start + 4 <= image.rgba8.count else { return [] }
        return image.rgba8[start..<(start + 4)].map(Int.init)
    }

    /// Whether `rgba`'s colour channels are each within `tolerance` of `want`'s.
    private func near(_ rgba: [Int], _ want: [Int], _ tolerance: Int) -> Bool {
        rgba.count >= 3 && want.count >= 3 && zip(rgba.prefix(3), want.prefix(3)).allSatisfy { abs($0 - $1) <= tolerance }
    }

    /// Every fixture folder scans to today's size, kind, capture date and camera, with no failures. No fixture
    /// carries Exif DateTimeOriginal, so each capture date is the file's creation date.
    @Test(.disabled("waits on SC-8")) func importFixturesScanAsToday() async throws {
        let root = try packageRoot()
        for folder in try expected().folders {
            let url = root.appending(path: folder.folder)
            let scan = try await decoder.scan(folder: url.path)
            #expect(scan.failures.isEmpty, "\(folder.folder): \(scan.failures)")
            let found = Dictionary(
                scan.candidates.map { (URL(fileURLWithPath: $0.path).lastPathComponent, $0) },
                uniquingKeysWith: { first, _ in first })
            #expect(Set(found.keys) == Set(folder.files.map(\.name)), "\(folder.folder)")
            for file in folder.files {
                let candidate = try #require(found[file.name], "\(folder.folder)/\(file.name) not scanned")
                #expect(candidate.pixelSize == size(file.pixelSize), "\(file.name)")
                #expect(candidate.kind.rawValue == file.kind, "\(file.name)")
                #expect(candidate.camera == CameraDetails(make: file.make, model: file.model), "\(file.name)")
                #expect(file.dateTimeOriginal == nil, "a fixture with a capture time needs its date checked here")
                let created = try url.appending(path: file.name).resourceValues(forKeys: [.creationDateKey]).creationDate
                #expect(candidate.captureDate == created, "\(file.name)")
            }
        }
    }

    /// Each scanned fixture decodes at full size to its scanned (upright) size.
    @Test(.disabled("waits on SC-8")) func importFixturesDecodeAtTheirScannedSize() async throws {
        let root = try packageRoot()
        for folder in try expected().folders {
            for file in folder.files {
                let path = root.appending(path: folder.folder).appending(path: file.name).path
                let image = try await decoder.decode(path: path, maxLongSide: nil)
                #expect(image.size == size(file.pixelSize), "\(file.name)")
            }
        }
    }

    /// The orientation-6 still (16 x 32 stored) decodes 32 x 16 with its upright corners red, green, blue, white.
    @Test(.disabled("waits on SC-8")) func orientationSixStillDecodesUpright() async throws {
        let root = try packageRoot()
        for still in try expected().upright {
            let image = try await decoder.decode(path: root.appending(path: still.path).path, maxLongSide: nil)
            #expect(image.size == size(still.pixelSize), "\(still.path)")
            let (right, bottom) = (image.size.width - 3, image.size.height - 3)
            #expect(near(pixel(image, 2, 2), still.corners.topLeft, 40), "top-left \(pixel(image, 2, 2))")
            #expect(near(pixel(image, right, 2), still.corners.topRight, 40), "top-right")
            #expect(near(pixel(image, 2, bottom), still.corners.bottomLeft, 40), "bottom-left")
            #expect(near(pixel(image, right, bottom), still.corners.bottomRight, 40), "bottom-right")
        }
    }

    /// RJ-X46's JPEG and HEIC (4032 x 3024 stored, orientation 6) scan and decode 3024 x 4032, and the two
    /// decodes agree within 3 levels on a 64-pixel grid, so neither path drops the orientation or the profile.
    @Test(.disabled("waits on SC-8")) func cameraPairDecodesUpright() async throws {
        let root = try packageRoot()
        let pair = try expected().rjX46
        let shown = try #require(size(pair.pixelSize))
        var images: [DisplayImage] = []
        for file in pair.files {
            let url = root.appending(path: file)
            let scan = try await decoder.scan(folder: url.deletingLastPathComponent().path)
            let candidate = scan.candidates.first { URL(fileURLWithPath: $0.path).lastPathComponent == url.lastPathComponent }
            #expect(candidate?.pixelSize == shown, "\(file) scans \(String(describing: candidate?.pixelSize))")
            let image = try await decoder.decode(path: url.path, maxLongSide: nil)
            #expect(image.size == shown, "\(file)")
            images.append(image)
        }
        let jpeg = try #require(images.first)
        let heic = try #require(images.last)
        try #require(images.count == 2 && jpeg.size == heic.size)
        for y in stride(from: 0, to: shown.height, by: 64) {
            for x in stride(from: 0, to: shown.width, by: 64) {
                let (a, b) = (pixel(jpeg, x, y), pixel(heic, x, y))
                #expect(near(a, b, pair.pairTolerance), "(\(x), \(y)): JPEG \(a), HEIC \(b)")
            }
        }
    }
}
#endif
