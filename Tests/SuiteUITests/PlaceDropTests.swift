// PlaceDropTests.swift: the place drop target's reader (placed-images PL-3): a `.png` URL and SVG data are taken, a
// `.txt` URL is refused without a highlight, a 40 MB file is refused with `sizeHelp`, the drop point is passed through,
// and a 30 MB file is read without holding the main actor over 50 ms. macOS only.
import Foundation
import SuiteKernel
@testable import SuiteUI
import Testing

@MainActor @Suite struct PlaceDropTests {
    private let all = Set(PlacedFormat.allCases)

    /// A file in a fresh temporary folder holding `data`.
    private func file(_ name: String, _ data: Data) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PlaceDropTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent(name)
        try data.write(to: url)
        return url
    }

    /// `bytes` long: the PNG signature, then zeros, written sparse.
    private func bigPNG(_ name: String, bytes: Int) throws -> URL {
        let url = try file(name, Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        let handle = try FileHandle(forWritingTo: url)
        try handle.truncate(atOffset: UInt64(bytes))
        try handle.close()
        return url
    }

    @Test func aPNGFileAndSVGDataAreTaken() throws {
        let png = try file("wide.png", GalleryPlaceImage.widePNG())
        let read = PlaceReader.readNow([.file(png), .data(name: "logo.svg", Data(GalleryPlaceImage.logoSVG.utf8))], formats: all)
        #expect(read.taken.map(\.name) == ["wide.png", "logo.svg"])
        #expect(read.refused == nil)
        #expect(PlaceReader.takes([["public.file-url", "public.png"]], formats: all))
        #expect(PlaceReader.takes([["public.svg-image"]], formats: all))
        #expect(!PlaceReader.takes([["public.svg-image"]], formats: [.png]))
    }

    @Test func aTextFileIsRefusedWithoutAHighlight() throws {
        #expect(!PlaceReader.takes([["public.file-url", "public.plain-text"]], formats: all))
        let text = try file("notes.txt", Data("hello".utf8))
        let read = PlaceReader.readNow([.file(text)], formats: all)
        #expect(read.taken.isEmpty)
        #expect(read.refused == PlaceRules.formatHelp)
    }

    @Test func aFortyMegabyteFileIsRefusedWithTheSizeHelp() throws {
        let big = try bigPNG("big.png", bytes: 40 << 20)
        let read = PlaceReader.readNow([.file(big)], formats: all)
        #expect(read.taken.isEmpty)
        #expect(read.refused == PlaceRules.sizeHelp)
        let pasted = PlaceReader.readNow([.data(name: "big.png", Data(count: PlaceRules.maxBytes + 1))], formats: all)
        #expect(pasted.refused == PlaceRules.sizeHelp)
    }

    @Test func theDropPointIsPassedThrough() async {
        var got: (names: [String], point: CGPoint)?
        let svg = PlaceItem.data(name: "logo.svg", Data(GalleryPlaceImage.logoSVG.utf8))
        _ = await PlaceReader.drop([svg], at: CGPoint(x: 12, y: 34), formats: all) { files, point in
            got = (files.map(\.name), point)
            return true
        }
        #expect(got?.names == ["logo.svg"])
        #expect(got?.point == CGPoint(x: 12, y: 34))
        var called = false
        _ = await PlaceReader.drop([.data(name: "notes.txt", Data("hello".utf8))], at: .zero, formats: all) { _, _ in
            called = true
            return true
        }
        #expect(!called)
    }

    @Test func largeFileOffMain() async throws {
        let large = try bigPNG("large.png", bytes: 30 << 20)
        let clock = ContinuousClock()
        var reading = true, longest = Duration.zero
        let beat = Task { @MainActor in
            var last = clock.now
            while reading {
                await Task.yield()
                longest = max(longest, clock.now - last)
                last = clock.now
            }
        }
        let read = await PlaceReader.read([.file(large)], formats: all)
        reading = false
        await beat.value
        #expect(read.taken.map(\.name) == ["large.png"])
        #expect(longest < .milliseconds(50))
    }
}
